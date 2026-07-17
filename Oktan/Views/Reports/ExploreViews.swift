import Charts
import SwiftUI

// MARK: - Range Selector

/// Segmented time-range control with period paging (chevrons) and label.
struct RangeSelectorView: View {
    @Binding var range: AnalyticsService.TimeRange
    @Binding var offset: Int

    var body: some View {
        VStack(spacing: 8) {
            Picker("Time range", selection: $range) {
                ForEach(AnalyticsService.TimeRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: range) { _, _ in offset = 0 }

            if range != .allTime {
                HStack {
                    Button {
                        offset -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous period")

                    Spacer()

                    Text(range.label(offset: offset))
                        .font(.subheadline.weight(.medium))
                        .contentTransition(.numericText())

                    Spacer()

                    Button {
                        offset += 1
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(offset >= 0)
                    .accessibilityLabel("Next period")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

// MARK: - Stat Tiles

/// 2x2 grid of period stats with deltas vs the previous period.
struct StatTilesView: View {
    let comparison: AnalyticsService.PeriodComparison
    let settings: AppSettings

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            tile("Distance", settings.formatDistance(comparison.current.distance),
                 delta: comparison.delta(\.distance), lowerIsBetter: false)
            tile("Spend", settings.formatCost(comparison.current.cost),
                 delta: comparison.delta(\.cost), lowerIsBetter: true)
            tile("Fill-ups", "\(comparison.current.fillUps)", delta: nil, lowerIsBetter: false)
            tile("Efficiency",
                 comparison.current.averageEfficiency.map { settings.formatEfficiency($0) } ?? "—",
                 delta: nil, lowerIsBetter: true)
        }
    }

    private func tile(_ label: String, _ value: String, delta: Double?, lowerIsBetter: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(settings.currentTheme.displayFont(relativeTo: .title3))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let delta {
                let isGood = lowerIsBetter ? delta <= 0 : delta >= 0
                Label("\(abs(delta).formatted(.number.precision(.fractionLength(0))))%",
                      systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isGood ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(settings.currentTheme.surfaceTint, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Spending Chart

/// Spending per bucket with tap/drag selection annotation.
struct SpendingChartView: View {
    let buckets: [AnalyticsService.Bucket]
    let range: AnalyticsService.TimeRange
    let settings: AppSettings

    @State private var selectedDate: Date?

    private var unit: Calendar.Component {
        (range == .week || range == .month) ? .day : .month
    }

    private var selectedBucket: AnalyticsService.Bucket? {
        guard let selectedDate else { return nil }
        return buckets.first {
            Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: unit)
        }
    }

    var body: some View {
        if buckets.allSatisfy({ $0.cost == 0 }) {
            Label("No spending in this period", systemImage: "chart.bar.xaxis")
                .foregroundStyle(.secondary)
        } else {
            Chart {
                ForEach(buckets) { bucket in
                    BarMark(
                        x: .value("Date", bucket.date, unit: unit),
                        y: .value("Spend", bucket.cost)
                    )
                    .foregroundStyle(settings.currentTheme.accent)
                    .opacity(selectedBucket == nil || selectedBucket?.date == bucket.date ? 1 : 0.4)
                }

                if let selectedBucket, selectedBucket.cost > 0 {
                    RuleMark(x: .value("Selected", selectedBucket.date, unit: unit))
                        .foregroundStyle(.secondary.opacity(0.3))
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit == .day
                                     ? selectedBucket.date.formatted(date: .abbreviated, time: .omitted)
                                     : selectedBucket.date.formatted(.dateTime.month(.wide).year()))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(settings.formatCost(selectedBucket.cost))
                                    .font(.caption.bold())
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .aspectRatio(1.8, contentMode: .fit)
            .accessibilityLabel("Spending chart with \(buckets.filter { $0.cost > 0 }.count) periods of spending")
        }
    }
}

// MARK: - Fuel Calendar Heatmap

/// Calendar heatmap of fill-up costs. Month ranges show a day grid;
/// year/all-time show month cells. Tapping a cell reveals its fill-ups.
struct FuelCalendarView: View {
    let entries: [FuelEntry]
    let range: AnalyticsService.TimeRange
    let offset: Int
    let settings: AppSettings

    @State private var selectedCellDate: Date?

    private var calendar: Calendar { .current }
    private var isMonthly: Bool { range == .year || range == .allTime }
    private var cellUnit: Calendar.Component { isMonthly ? .month : .day }

    /// All cells in the shown span with their total cost
    private var cells: [(date: Date, cost: Double)] {
        var totals: [Date: Double] = [:]
        for entry in entries {
            if let start = calendar.dateInterval(of: cellUnit, for: entry.date)?.start {
                totals[start, default: 0] += entry.totalCost
            }
        }

        let span: DateInterval
        if let interval = (range == .allTime ? nil : range.interval(offset: offset)) {
            span = interval
        } else if let first = entries.first?.date, let last = entries.last?.date {
            span = DateInterval(
                start: calendar.dateInterval(of: cellUnit, for: first)?.start ?? first,
                end: calendar.dateInterval(of: cellUnit, for: last)?.end ?? last
            )
        } else {
            return []
        }

        var result: [(Date, Double)] = []
        var cursor = calendar.dateInterval(of: cellUnit, for: span.start)?.start ?? span.start
        while cursor < span.end {
            result.append((cursor, totals[cursor] ?? 0))
            guard let next = calendar.date(byAdding: cellUnit, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private var maxCost: Double {
        max(cells.map(\.cost).max() ?? 0, 1)
    }

    private var selectedEntries: [FuelEntry] {
        guard let selectedCellDate else { return [] }
        return entries.filter {
            calendar.isDate($0.date, equalTo: selectedCellDate, toGranularity: cellUnit)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: isMonthly ? 6 : 7), spacing: 4) {
                ForEach(cells, id: \.date) { cell in
                    let intensity = cell.cost / maxCost
                    Button {
                        selectedCellDate = selectedCellDate == cell.date ? nil : cell.date
                    } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(cell.cost > 0
                                  ? settings.currentTheme.accent.opacity(0.25 + 0.75 * intensity)
                                  : Color.primary.opacity(0.06))
                            .aspectRatio(isMonthly ? 1.6 : 1, contentMode: .fit)
                            .overlay {
                                Text(isMonthly
                                     ? cell.date.formatted(.dateTime.month(.narrow))
                                     : cell.date.formatted(.dateTime.day()))
                                    .font(.system(size: 9))
                                    .foregroundStyle(cell.cost > maxCost * 0.5 ? .white : .secondary)
                            }
                            .overlay {
                                if selectedCellDate == cell.date {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.primary, lineWidth: 1.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(cellAccessibilityLabel(cell))
                }
            }

            if !selectedEntries.isEmpty {
                ForEach(selectedEntries) { entry in
                    HStack {
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                        Text(entry.gasStation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(settings.formatCost(entry.totalCost))
                            .font(.caption.bold())
                    }
                }
            } else if selectedCellDate != nil {
                Text("No fill-ups in this cell")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cellAccessibilityLabel(_ cell: (date: Date, cost: Double)) -> String {
        let dateText = isMonthly
            ? cell.date.formatted(.dateTime.month(.wide).year())
            : cell.date.formatted(date: .long, time: .omitted)
        return cell.cost > 0 ? "\(dateText), \(settings.formatCost(cell.cost))" : "\(dateText), no fill-up"
    }
}

// MARK: - Station Scoreboard

struct StationScoreboardView: View {
    let entries: [FuelEntry]
    let settings: AppSettings

    private var stations: [AnalyticsService.StationStats] {
        AnalyticsService.stationBreakdown(from: entries)
    }

    var body: some View {
        let stations = self.stations
        let maxSpend = max(stations.map(\.totalSpend).max() ?? 0, 1)

        if stations.isEmpty {
            Label("Log stations with your fill-ups to compare them", systemImage: "fuelpump")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(stations) { station in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(station.name)
                                .font(.subheadline.weight(.medium))
                            Text("· \(station.fillUps) fill-ups")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(station.averagePrice.formatted(.number.precision(.fractionLength(2))))/L")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(settings.currentTheme.accent)
                                .frame(width: proxy.size.width * station.totalSpend / maxSpend)
                        }
                        .frame(height: 8)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(station.name): \(settings.formatCost(station.totalSpend)) across \(station.fillUps) fill-ups")
                }

                if let savings = AnalyticsService.projectedAnnualSavings(from: entries) {
                    Label(
                        "Filling only at \(savings.station) would save about \(settings.formatCost(savings.amount)) per year.",
                        systemImage: "lightbulb.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Drive Mode What-If

struct EcoWhatIfView: View {
    let entries: [FuelEntry]
    let settings: AppSettings

    @State private var ecoShare: Double = 1.0

    var body: some View {
        if let whatIf = AnalyticsService.ecoWhatIf(from: entries) {
            let averagePrice = entries.isEmpty ? 0 : entries.reduce(0) { $0 + $1.pricePerLiter } / Double(entries.count)
            let savings = whatIf.annualSavings(averagePrice: averagePrice, ecoShare: ecoShare)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Your average")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(settings.formatEfficiency(whatIf.currentEfficiency))
                            .font(.headline)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Eco average")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(settings.formatEfficiency(whatIf.ecoEfficiency))
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("If \(ecoShare.formatted(.percent.precision(.fractionLength(0)))) of driving were Eco")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Slider(value: $ecoShare, in: 0...1, step: 0.1)
                        .accessibilityLabel("Share of Eco driving")
                }

                Label(
                    "You'd save about \(settings.formatCost(max(savings, 0))) per year.",
                    systemImage: "leaf.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)
            }
        } else {
            Label("Log fill-ups in Eco and other modes to unlock this comparison", systemImage: "leaf")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Journey Chart

/// Cumulative spend over time with a scrubber showing distance and cost/km.
struct JourneyChartView: View {
    let entries: [FuelEntry]
    let settings: AppSettings

    @State private var selectedDate: Date?

    private struct JourneyPoint: Identifiable {
        let date: Date
        let cumulativeCost: Double
        let cumulativeKM: Double
        var id: Date { date }
    }

    private var points: [JourneyPoint] {
        var cost = 0.0
        var km = 0.0
        return entries.sorted { $0.date < $1.date }.map { entry in
            cost += entry.totalCost
            km += entry.distance ?? 0
            return JourneyPoint(date: entry.date, cumulativeCost: cost, cumulativeKM: km)
        }
    }

    var body: some View {
        let points = self.points

        if points.count < 2 {
            Label("Add more fill-ups to see your journey", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                .foregroundStyle(.secondary)
        } else {
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Spend", point.cumulativeCost)
                    )
                    .foregroundStyle(settings.currentTheme.accent.opacity(0.12))
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Spend", point.cumulativeCost)
                    )
                    .foregroundStyle(settings.currentTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.monotone)
                }

                if let selectedDate,
                   let point = points.last(where: { $0.date <= selectedDate }) ?? points.first {
                    RuleMark(x: .value("Selected", point.date))
                        .foregroundStyle(.secondary.opacity(0.3))
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(settings.formatCost(point.cumulativeCost))
                                    .font(.caption.bold())
                                Text(settings.formatDistance(point.cumulativeKM))
                                    .font(.caption2)
                                if point.cumulativeKM > 0 {
                                    Text("\(settings.formatCostPerDistance(point.cumulativeCost / point.cumulativeKM))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    PointMark(
                        x: .value("Selected", point.date),
                        y: .value("Spend", point.cumulativeCost)
                    )
                    .foregroundStyle(settings.currentTheme.accent)
                }
            }
            .chartXSelection(value: $selectedDate)
            .aspectRatio(1.6, contentMode: .fit)
            .accessibilityLabel("Cumulative spending journey across \(points.count) fill-ups")
        }
    }
}

// MARK: - Price Timeline

struct PriceTimelineView: View {
    let entries: [FuelEntry]
    let settings: AppSettings

    var body: some View {
        let sorted = entries.sorted { $0.date < $1.date }

        if sorted.count < 2 {
            Label("Track more fill-ups to see price history", systemImage: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.secondary)
        } else {
            let average = sorted.reduce(0) { $0 + $1.pricePerLiter } / Double(sorted.count)

            VStack(alignment: .leading, spacing: 10) {
                Chart {
                    RuleMark(y: .value("Average", average))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .topTrailing) {
                            Text("avg \(average.formatted(.number.precision(.fractionLength(2))))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                    ForEach(sorted) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Price", entry.pricePerLiter)
                        )
                        .foregroundStyle(.secondary.opacity(0.5))
                        .interpolationMethod(.stepEnd)

                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Price", entry.pricePerLiter)
                        )
                        .foregroundStyle(entry.pricePerLiter <= average ? Color.green : Color.red)
                        .symbolSize(50)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .aspectRatio(2, contentMode: .fit)
                .accessibilityLabel("Price per liter over time for \(sorted.count) fill-ups")

                if let score = AnalyticsService.fillTimingScore(from: sorted) {
                    Label(
                        "Fill timing: \(score.formatted(.percent.precision(.fractionLength(0)))) of your fill-ups were at or below the average price.",
                        systemImage: "target"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Records Board

struct RecordsView: View {
    let entries: [FuelEntry]
    let settings: AppSettings

    private var records: [AnalyticsService.FuelRecord] {
        var result: [AnalyticsService.FuelRecord] = []

        if let longest = entries.filter({ $0.distance != nil }).max(by: { ($0.distance ?? 0) < ($1.distance ?? 0) }),
           let distance = longest.distance {
            result.append(.init(
                id: "longest",
                title: String(localized: "Longest tank range"),
                value: settings.formatDistance(distance),
                subtitle: longest.date.formatted(date: .abbreviated, time: .omitted),
                icon: "road.lanes"
            ))
        }
        if let cheapest = entries.min(by: { $0.pricePerLiter < $1.pricePerLiter }) {
            result.append(.init(
                id: "cheapest",
                title: String(localized: "Cheapest fill"),
                value: "\(cheapest.pricePerLiter.formatted(.number.precision(.fractionLength(2))))/L",
                subtitle: "\(cheapest.gasStation) · \(cheapest.date.formatted(date: .abbreviated, time: .omitted))",
                icon: "tag.fill"
            ))
        }
        if let best = entries.filter({ $0.litersPer100KM != nil }).min(by: { ($0.litersPer100KM ?? .infinity) < ($1.litersPer100KM ?? .infinity) }),
           let efficiency = best.litersPer100KM {
            result.append(.init(
                id: "best-efficiency",
                title: String(localized: "Best efficiency"),
                value: settings.formatEfficiency(efficiency),
                subtitle: "\(best.driveMode.rawValue) · \(best.date.formatted(date: .abbreviated, time: .omitted))",
                icon: "leaf.fill"
            ))
        }
        if let biggest = entries.max(by: { $0.totalCost < $1.totalCost }) {
            result.append(.init(
                id: "biggest",
                title: String(localized: "Biggest fill-up"),
                value: settings.formatCost(biggest.totalCost),
                subtitle: "\(settings.formatVolume(biggest.totalLiters)) · \(biggest.date.formatted(date: .abbreviated, time: .omitted))",
                icon: "fuelpump.fill"
            ))
        }
        return result
    }

    var body: some View {
        let records = self.records
        if records.isEmpty {
            Label("Records appear once you have some fill-ups", systemImage: "trophy")
                .foregroundStyle(.secondary)
        } else {
            ForEach(records) { record in
                HStack {
                    Image(systemName: record.icon)
                        .foregroundStyle(settings.currentTheme.accent)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(record.title)
                            .font(.subheadline)
                        Text(record.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(record.value)
                        .font(settings.currentTheme.displayFont(relativeTo: .headline))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(record.title): \(record.value), \(record.subtitle)")
            }
        }
    }
}
