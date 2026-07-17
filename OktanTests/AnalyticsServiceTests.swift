import XCTest
@testable import oktan

@MainActor
final class AnalyticsServiceTests: XCTestCase {

    private func entry(daysAgo: Int, liters: Double = 40, price: Double = 2.0,
                       station: String = "Pearl", mode: FuelEntry.DriveMode = .normal,
                       start: Double? = nil, end: Double? = nil,
                       now: Date = Date()) -> FuelEntry {
        FuelEntry(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!,
            odometerStart: start,
            odometerEnd: end,
            totalLiters: liters,
            pricePerLiter: price,
            gasStation: station,
            driveMode: mode,
            isFullRefill: true
        )
    }

    // MARK: - Time Ranges

    func testWeekIntervalContainsNow() {
        let now = Date()
        let interval = AnalyticsService.TimeRange.week.interval(offset: 0, now: now)
        XCTAssertNotNil(interval)
        XCTAssertTrue(interval!.contains(now))
    }

    func testOffsetShiftsPeriodBack() {
        let now = Date()
        let current = AnalyticsService.TimeRange.month.interval(offset: 0, now: now)!
        let previous = AnalyticsService.TimeRange.month.interval(offset: -1, now: now)!
        XCTAssertEqual(previous.end, current.start)
    }

    func testAllTimeHasNoInterval() {
        XCTAssertNil(AnalyticsService.TimeRange.allTime.interval(offset: 0))
    }

    func testEntriesScopedToInterval() {
        let now = Date()
        let entries = [entry(daysAgo: 400, now: now), entry(daysAgo: 1, now: now)]
        let interval = AnalyticsService.TimeRange.year.interval(offset: 0, now: now)
        let scoped = AnalyticsService.entries(entries, in: interval)
        XCTAssertEqual(scoped.count, 1)
        XCTAssertEqual(AnalyticsService.entries(entries, in: nil).count, 2)
    }

    // MARK: - Period Stats

    func testPeriodStatsComputation() {
        let now = Date()
        let entries = [
            entry(daysAgo: 2, liters: 40, price: 2.0, start: 0, end: 400, now: now),
            entry(daysAgo: 1, liters: 42, price: 2.0, start: 400, end: 800, now: now)
        ]
        let stats = AnalyticsService.PeriodStats.compute(from: entries)
        XCTAssertEqual(stats.fillUps, 2)
        XCTAssertEqual(stats.distance, 800, accuracy: 0.01)
        XCTAssertEqual(stats.liters, 82, accuracy: 0.01)
        XCTAssertEqual(stats.cost, 164, accuracy: 0.01)
        XCTAssertEqual(stats.averageEfficiency ?? 0, 82.0 / 800 * 100, accuracy: 0.01)
    }

    func testComparisonDeltas() {
        let current = AnalyticsService.PeriodStats(distance: 400, liters: 40, cost: 110, fillUps: 1, averageEfficiency: 10)
        let previous = AnalyticsService.PeriodStats(distance: 400, liters: 40, cost: 100, fillUps: 1, averageEfficiency: 10)
        let comparison = AnalyticsService.PeriodComparison(current: current, previous: previous)
        XCTAssertEqual(comparison.delta(\.cost) ?? 0, 10, accuracy: 0.01)
        XCTAssertNil(AnalyticsService.PeriodComparison(current: current, previous: nil).delta(\.cost))
    }

    // MARK: - Spending Buckets

    func testSpendingBucketsCoverWholeWeek() {
        let now = Date()
        let entries = [entry(daysAgo: 0, liters: 40, price: 2.0, now: now)]
        let buckets = AnalyticsService.spendingBuckets(entries: entries, range: .week, offset: 0, now: now)
        XCTAssertEqual(buckets.count, 7)
        XCTAssertEqual(buckets.reduce(0) { $0 + $1.cost }, 80, accuracy: 0.01)
    }

    func testSpendingBucketsYearHasTwelveMonths() {
        let now = Date()
        let entries = [entry(daysAgo: 0, now: now)]
        let buckets = AnalyticsService.spendingBuckets(entries: entries, range: .year, offset: 0, now: now)
        XCTAssertEqual(buckets.count, 12)
    }

    // MARK: - Stations

    func testStationBreakdownSortedBySpend() {
        let now = Date()
        let entries = [
            entry(daysAgo: 3, liters: 40, price: 2.0, station: "Pearl", now: now),
            entry(daysAgo: 2, liters: 40, price: 2.0, station: "Pearl", now: now),
            entry(daysAgo: 1, liters: 40, price: 1.9, station: "Onaiza", now: now)
        ]
        let stations = AnalyticsService.stationBreakdown(from: entries)
        XCTAssertEqual(stations.first?.name, "Pearl")
        XCTAssertEqual(stations.first?.fillUps, 2)
        XCTAssertEqual(stations.last?.averagePrice ?? 0, 1.9, accuracy: 0.001)
    }

    func testProjectedSavingsRequiresCheaperStation() {
        let now = Date()
        // 60-day span, Onaiza consistently cheaper
        let entries = [
            entry(daysAgo: 60, price: 2.1, station: "Pearl", now: now),
            entry(daysAgo: 40, price: 2.1, station: "Pearl", now: now),
            entry(daysAgo: 20, price: 1.9, station: "Onaiza", now: now),
            entry(daysAgo: 0, price: 1.9, station: "Onaiza", now: now)
        ].sorted { $0.date < $1.date }

        let savings = AnalyticsService.projectedAnnualSavings(from: entries)
        XCTAssertEqual(savings?.station, "Onaiza")
        XCTAssertGreaterThan(savings?.amount ?? 0, 0)
    }

    // MARK: - Eco What-If

    func testEcoWhatIfComputesSavings() {
        let now = Date()
        let entries = [
            entry(daysAgo: 90, liters: 40, mode: .eco, start: 0, end: 440, now: now),      // 9.1 L/100
            entry(daysAgo: 60, liters: 42, mode: .sport, start: 440, end: 790, now: now),  // 12.0 L/100
            entry(daysAgo: 30, liters: 41, mode: .normal, start: 790, end: 1180, now: now) // 10.5 L/100
        ].sorted { $0.date < $1.date }

        let whatIf = AnalyticsService.ecoWhatIf(from: entries)
        XCTAssertNotNil(whatIf)
        XCTAssertLessThan(whatIf!.ecoEfficiency, whatIf!.currentEfficiency)
        XCTAssertGreaterThan(whatIf!.annualSavings(averagePrice: 2.0, ecoShare: 1.0), 0)
        XCTAssertEqual(whatIf!.annualSavings(averagePrice: 2.0, ecoShare: 0.0), 0, accuracy: 0.001)
    }

    // MARK: - Fill Timing

    func testFillTimingScore() {
        let now = Date()
        let entries = [
            entry(daysAgo: 3, price: 1.9, now: now),
            entry(daysAgo: 2, price: 2.0, now: now),
            entry(daysAgo: 1, price: 2.2, now: now)
        ]
        // avg ~2.033; two fills at/below average
        let score = AnalyticsService.fillTimingScore(from: entries)
        XCTAssertEqual(score ?? 0, 2.0 / 3.0, accuracy: 0.01)
        XCTAssertNil(AnalyticsService.fillTimingScore(from: Array(entries.prefix(2))))
    }
}
