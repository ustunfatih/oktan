import Foundation

/// Time-range analytics: period math, per-period stats with deltas, and the
/// datasets behind the Explore visualizations.
enum AnalyticsService {

    // MARK: - Time Ranges

    enum TimeRange: String, CaseIterable, Identifiable {
        case week
        case month
        case year
        case allTime

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .week: return String(localized: "Week")
            case .month: return String(localized: "Month")
            case .year: return String(localized: "Year")
            case .allTime: return String(localized: "All")
            }
        }

        private var component: Calendar.Component? {
            switch self {
            case .week: return .weekOfYear
            case .month: return .month
            case .year: return .year
            case .allTime: return nil
            }
        }

        /// The date interval for this range shifted by `offset` periods
        /// (0 = current, -1 = previous, ...). nil means "everything".
        func interval(offset: Int, now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
            guard let component else { return nil }
            guard let shifted = calendar.date(byAdding: component, value: offset, to: now),
                  let interval = calendar.dateInterval(of: component, for: shifted) else { return nil }
            return interval
        }

        /// Human label for the period at `offset`
        func label(offset: Int, now: Date = Date(), calendar: Calendar = .current) -> String {
            guard let interval = interval(offset: offset, now: now, calendar: calendar) else {
                return String(localized: "All time")
            }
            switch self {
            case .week:
                if offset == 0 { return String(localized: "This week") }
                let end = interval.end.addingTimeInterval(-1)
                return "\(interval.start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
            case .month:
                return interval.start.formatted(.dateTime.month(.wide).year())
            case .year:
                return interval.start.formatted(.dateTime.year())
            case .allTime:
                return String(localized: "All time")
            }
        }
    }

    static func entries(_ entries: [FuelEntry], in interval: DateInterval?) -> [FuelEntry] {
        guard let interval else { return entries }
        return entries.filter { interval.contains($0.date) }
    }

    // MARK: - Period Stats

    struct PeriodStats {
        let distance: Double
        let liters: Double
        let cost: Double
        let fillUps: Int
        let averageEfficiency: Double?

        static func compute(from entries: [FuelEntry]) -> PeriodStats {
            let completed = entries.filter { $0.distance != nil }
            let distance = completed.compactMap(\.distance).reduce(0, +)
            let litersWithDistance = completed.reduce(0) { $0 + $1.totalLiters }
            return PeriodStats(
                distance: distance,
                liters: entries.reduce(0) { $0 + $1.totalLiters },
                cost: entries.reduce(0) { $0 + $1.totalCost },
                fillUps: entries.count,
                averageEfficiency: distance > 0 ? (litersWithDistance / distance) * 100 : nil
            )
        }
    }

    /// Stats for the given period plus percentage deltas vs the previous one.
    struct PeriodComparison {
        let current: PeriodStats
        let previous: PeriodStats?

        func delta(_ keyPath: KeyPath<PeriodStats, Double>) -> Double? {
            guard let previous, previous[keyPath: keyPath] > 0 else { return nil }
            return ((current[keyPath: keyPath] - previous[keyPath: keyPath]) / previous[keyPath: keyPath]) * 100
        }
    }

    static func compare(entries allEntries: [FuelEntry], range: TimeRange, offset: Int, now: Date = Date()) -> PeriodComparison {
        let interval = range.interval(offset: offset, now: now)
        let current = PeriodStats.compute(from: entries(allEntries, in: interval))
        guard range != .allTime else {
            return PeriodComparison(current: current, previous: nil)
        }
        let previousInterval = range.interval(offset: offset - 1, now: now)
        let previous = PeriodStats.compute(from: entries(allEntries, in: previousInterval))
        return PeriodComparison(current: current, previous: previous.fillUps > 0 ? previous : nil)
    }

    // MARK: - Spending Buckets

    struct Bucket: Identifiable {
        let date: Date
        let cost: Double
        var id: Date { date }
    }

    /// Continuous spending buckets over the period: daily for week/month,
    /// monthly for year and all-time (zeros included so rhythm is visible).
    static func spendingBuckets(entries allEntries: [FuelEntry], range: TimeRange, offset: Int, now: Date = Date(), calendar: Calendar = .current) -> [Bucket] {
        let interval = range.interval(offset: offset, now: now, calendar: calendar)
        let scoped = entries(allEntries, in: interval)

        let bucketComponent: Calendar.Component = (range == .week || range == .month) ? .day : .month

        var totals: [Date: Double] = [:]
        for entry in scoped {
            guard let bucketStart = calendar.dateInterval(of: bucketComponent, for: entry.date)?.start else { continue }
            totals[bucketStart, default: 0] += entry.totalCost
        }

        // Establish the span to fill with zero buckets
        let span: DateInterval
        if let interval {
            span = interval
        } else {
            guard let first = scoped.first?.date, let last = scoped.last?.date,
                  let start = calendar.dateInterval(of: bucketComponent, for: first)?.start,
                  let end = calendar.dateInterval(of: bucketComponent, for: last)?.end else { return [] }
            span = DateInterval(start: start, end: end)
        }

        var buckets: [Bucket] = []
        var cursor = calendar.dateInterval(of: bucketComponent, for: span.start)?.start ?? span.start
        while cursor < span.end {
            buckets.append(Bucket(date: cursor, cost: totals[cursor] ?? 0))
            guard let next = calendar.date(byAdding: bucketComponent, value: 1, to: cursor) else { break }
            cursor = next
        }
        return buckets
    }

    // MARK: - Station Scoreboard

    struct StationStats: Identifiable {
        let name: String
        let totalSpend: Double
        let averagePrice: Double
        let fillUps: Int
        var id: String { name }
    }

    static func stationBreakdown(from entries: [FuelEntry]) -> [StationStats] {
        let grouped = Dictionary(grouping: entries.filter { !$0.gasStation.isEmpty }) { $0.gasStation }
        return grouped.map { name, group in
            StationStats(
                name: name,
                totalSpend: group.reduce(0) { $0 + $1.totalCost },
                averagePrice: group.reduce(0) { $0 + $1.pricePerLiter } / Double(group.count),
                fillUps: group.count
            )
        }
        .sorted { $0.totalSpend > $1.totalSpend }
    }

    /// Projected yearly savings if every fill-up happened at the cheapest
    /// station (needs at least two stations and a meaningful history span).
    static func projectedAnnualSavings(from entries: [FuelEntry]) -> (station: String, amount: Double)? {
        let stations = stationBreakdown(from: entries).filter { $0.fillUps >= 1 }
        guard stations.count >= 2,
              let cheapest = stations.min(by: { $0.averagePrice < $1.averagePrice }),
              let first = entries.first?.date, let last = entries.last?.date else { return nil }

        let spanDays = max(last.timeIntervalSince(first) / 86_400, 1)
        guard spanDays >= 30 else { return nil }

        let totalLiters = entries.reduce(0) { $0 + $1.totalLiters }
        let averagePaid = entries.reduce(0) { $0 + $1.totalCost } / totalLiters
        let perLiterSaving = averagePaid - cheapest.averagePrice
        guard perLiterSaving > 0.001 else { return nil }

        let annualLiters = totalLiters / spanDays * 365
        return (cheapest.name, perLiterSaving * annualLiters)
    }

    // MARK: - Drive Mode What-If

    struct EcoWhatIf {
        let currentEfficiency: Double
        let ecoEfficiency: Double
        let annualKM: Double
        /// Cost saved per year if all driving matched Eco efficiency
        func annualSavings(averagePrice: Double, ecoShare: Double) -> Double {
            let blended = currentEfficiency + (ecoEfficiency - currentEfficiency) * ecoShare
            let litersSavedPer100 = currentEfficiency - blended
            return litersSavedPer100 / 100 * annualKM * averagePrice
        }
    }

    static func ecoWhatIf(from entries: [FuelEntry]) -> EcoWhatIf? {
        let completed = entries.filter { $0.distance != nil }
        let ecoEntries = completed.filter { $0.driveMode == .eco }
        guard !ecoEntries.isEmpty, completed.count >= 3,
              let first = entries.first?.date, let last = entries.last?.date else { return nil }

        func efficiency(_ group: [FuelEntry]) -> Double? {
            let distance = group.compactMap(\.distance).reduce(0, +)
            guard distance > 0 else { return nil }
            return group.reduce(0) { $0 + $1.totalLiters } / distance * 100
        }

        guard let current = efficiency(completed), let eco = efficiency(ecoEntries), eco < current else { return nil }

        let spanDays = max(last.timeIntervalSince(first) / 86_400, 1)
        let totalDistance = completed.compactMap(\.distance).reduce(0, +)
        let annualKM = totalDistance / spanDays * 365

        return EcoWhatIf(currentEfficiency: current, ecoEfficiency: eco, annualKM: annualKM)
    }

    // MARK: - Price Timeline

    /// Share of fill-ups bought at or below the period's average price (0-1).
    static func fillTimingScore(from entries: [FuelEntry]) -> Double? {
        guard entries.count >= 3 else { return nil }
        let average = entries.reduce(0) { $0 + $1.pricePerLiter } / Double(entries.count)
        let goodFills = entries.filter { $0.pricePerLiter <= average + 0.0001 }.count
        return Double(goodFills) / Double(entries.count)
    }

    // MARK: - Records

    struct FuelRecord: Identifiable {
        let id: String
        let title: String
        let value: String
        let subtitle: String
        let icon: String
    }
}
