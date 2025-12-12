import XCTest
@testable import oktan

/// Tests for ChartDataService calculations and data aggregation
final class ChartDataServiceTests: XCTestCase {
    
    // MARK: - Test Data
    
    private func createTestEntries() -> [FuelEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            FuelEntry(
                date: calendar.date(byAdding: .day, value: -90, to: now)!,
                odometerStart: 1000,
                odometerEnd: 1500,
                totalLiters: 45,
                pricePerLiter: 1.50,
                gasStation: "Shell",
                driveMode: .eco,
                isFullRefill: true
            ),
            FuelEntry(
                date: calendar.date(byAdding: .day, value: -60, to: now)!,
                odometerStart: 1500,
                odometerEnd: 2000,
                totalLiters: 50,
                pricePerLiter: 1.55,
                gasStation: "BP",
                driveMode: .normal,
                isFullRefill: true
            ),
            FuelEntry(
                date: calendar.date(byAdding: .day, value: -30, to: now)!,
                odometerStart: 2000,
                odometerEnd: 2400,
                totalLiters: 48,
                pricePerLiter: 1.60,
                gasStation: "Total",
                driveMode: .sport,
                isFullRefill: true
            ),
            FuelEntry(
                date: calendar.date(byAdding: .day, value: -7, to: now)!,
                odometerStart: 2400,
                odometerEnd: 2900,
                totalLiters: 52,
                pricePerLiter: 1.58,
                gasStation: "Shell",
                driveMode: .eco,
                isFullRefill: true
            )
        ]
    }
    
    // MARK: - Efficiency Trend Tests
    
    func testEfficiencyTrendReturnsCorrectCount() {
        let entries = createTestEntries()
        let trend = ChartDataService.efficiencyTrend(from: entries)
        
        XCTAssertEqual(trend.count, 4, "Should return all entries with efficiency data")
    }
    
    func testEfficiencyTrendIsSortedByDate() {
        let entries = createTestEntries()
        let trend = ChartDataService.efficiencyTrend(from: entries)
        
        for i in 1..<trend.count {
            XCTAssertLessThan(trend[i-1].date, trend[i].date, "Data should be sorted by date ascending")
        }
    }
    
    func testEfficiencyTrendValuesAreCorrect() {
        let entries = createTestEntries()
        let trend = ChartDataService.efficiencyTrend(from: entries)
        
        // First entry: 45L / 500km * 100 = 9.0 L/100km
        XCTAssertEqual(trend[0].value, 9.0, accuracy: 0.01)
        
        // Second entry: 50L / 500km * 100 = 10.0 L/100km
        XCTAssertEqual(trend[1].value, 10.0, accuracy: 0.01)
        
        // Third entry: 48L / 400km * 100 = 12.0 L/100km
        XCTAssertEqual(trend[2].value, 12.0, accuracy: 0.01)
        
        // Fourth entry: 52L / 500km * 100 = 10.4 L/100km
        XCTAssertEqual(trend[3].value, 10.4, accuracy: 0.01)
    }
    
    func testEfficiencyTrendFiltersEntriesWithoutOdometer() {
        var entries = createTestEntries()
        entries.append(FuelEntry(
            date: Date(),
            odometerStart: nil,
            odometerEnd: nil,
            totalLiters: 40,
            pricePerLiter: 1.50,
            gasStation: "Test"
        ))
        
        let trend = ChartDataService.efficiencyTrend(from: entries)
        XCTAssertEqual(trend.count, 4, "Should filter entries without odometer readings")
    }
    
    // MARK: - Rolling Average Tests
    
    func testRollingAverageWithDefaultWindow() {
        let entries = createTestEntries()
        let rolling = ChartDataService.rollingAverageEfficiency(from: entries, windowSize: 3)
        
        // Window of 3, so we get count - 2 points
        XCTAssertEqual(rolling.count, 2)
        
        // First rolling window: (9.0 + 10.0 + 12.0) / 3 = 10.33
        XCTAssertEqual(rolling[0].value, 10.33, accuracy: 0.1)
        
        // Second rolling window: (10.0 + 12.0 + 10.4) / 3 = 10.8
        XCTAssertEqual(rolling[1].value, 10.8, accuracy: 0.1)
    }
    
    func testRollingAverageWithInsufficientData() {
        let entries = [createTestEntries()[0], createTestEntries()[1]]
        let rolling = ChartDataService.rollingAverageEfficiency(from: entries, windowSize: 3)
        
        XCTAssertTrue(rolling.isEmpty, "Should return empty for insufficient data")
    }
    
    // MARK: - Cost Trend Tests
    
    func testCostPerKMTrend() {
        let entries = createTestEntries()
        let trend = ChartDataService.costPerKMTrend(from: entries)
        
        XCTAssertEqual(trend.count, 4)
        
        // First entry: (45 * 1.50) / 500 = 0.135
        XCTAssertEqual(trend[0].value, 0.135, accuracy: 0.001)
    }
    
    func testMonthlyCostTrend() {
        let entries = createTestEntries()
        let monthly = ChartDataService.monthlyCostTrend(from: entries)
        
        // Should aggregate into months
        XCTAssertGreaterThan(monthly.count, 0)
    }
    
    func testWeeklySpending() {
        let entries = createTestEntries()
        let weekly = ChartDataService.weeklySpending(from: entries)
        
        XCTAssertGreaterThan(weekly.count, 0)
        
        // Verify totals are correct
        let totalFromWeekly = weekly.reduce(0) { $0 + $1.value }
        let totalFromEntries = entries.reduce(0) { $0 + $1.totalCost }
        XCTAssertEqual(totalFromWeekly, totalFromEntries, accuracy: 0.01)
    }
    
    // MARK: - Drive Mode Comparison Tests
    
    func testDriveModeComparison() {
        let entries = createTestEntries()
        let comparison = ChartDataService.driveModeComparison(from: entries)
        
        XCTAssertEqual(comparison.count, 3, "Should have data for all drive modes used")
        
        // Find Eco mode
        if let eco = comparison.first(where: { $0.category == "Eco" }) {
            // Two Eco entries: (9.0 + 10.4) / 2 = 9.7
            XCTAssertEqual(eco.value, 9.7, accuracy: 0.1)
        } else {
            XCTFail("Should have Eco mode data")
        }
    }
    
    // MARK: - Monthly Aggregation Tests
    
    func testMonthlyAggregation() {
        let entries = createTestEntries()
        let monthly = ChartDataService.aggregateMonthly(from: entries)
        
        XCTAssertGreaterThan(monthly.count, 0)
        
        // Verify totals add up
        let totalDistance = monthly.reduce(0) { $0 + $1.totalDistance }
        let expectedDistance = entries.compactMap { $0.distance }.reduce(0, +)
        XCTAssertEqual(totalDistance, expectedDistance, accuracy: 0.01)
        
        let totalCost = monthly.reduce(0) { $0 + $1.totalCost }
        let expectedCost = entries.reduce(0) { $0 + $1.totalCost }
        XCTAssertEqual(totalCost, expectedCost, accuracy: 0.01)
    }
    
    func testMonthlyAggregationIsSortedByDate() {
        let entries = createTestEntries()
        let monthly = ChartDataService.aggregateMonthly(from: entries)
        
        for i in 1..<monthly.count {
            XCTAssertLessThan(monthly[i-1].month, monthly[i].month)
        }
    }
    
    // MARK: - Period Comparison Tests
    
    func testMonthOverMonthComparison() {
        let entries = createTestEntries()
        let comparison = ChartDataService.monthOverMonthComparison(from: entries)
        
        XCTAssertNotNil(comparison.currentPeriod)
    }
    
    // MARK: - Fill-up Frequency Tests
    
    func testAverageDaysBetweenFillups() {
        let entries = createTestEntries()
        let avgDays = ChartDataService.averageDaysBetweenFillups(from: entries)
        
        XCTAssertNotNil(avgDays)
        // 90 days spread across 4 entries means ~30 days average
        XCTAssertEqual(avgDays!, 27.67, accuracy: 5.0) // Approximate due to date calculation
    }
    
    func testAverageDaysBetweenFillupsWithOneEntry() {
        let entries = [createTestEntries()[0]]
        let avgDays = ChartDataService.averageDaysBetweenFillups(from: entries)
        
        XCTAssertNil(avgDays, "Should return nil for single entry")
    }
    
    func testFillupsByDayOfWeek() {
        let entries = createTestEntries()
        let byDay = ChartDataService.fillupsByDayOfWeek(from: entries)
        
        XCTAssertEqual(byDay.count, 7, "Should have all 7 days")
        
        let totalFillups = byDay.reduce(0) { $0 + Int($1.value) }
        XCTAssertEqual(totalFillups, entries.count)
    }
    
    // MARK: - Insights Tests
    
    func testGenerateInsights() {
        let entries = createTestEntries()
        let insights = ChartDataService.generateInsights(from: entries)
        
        XCTAssertGreaterThan(insights.count, 0, "Should generate some insights")
    }
    
    func testGenerateInsightsWithEmptyData() {
        let insights = ChartDataService.generateInsights(from: [])
        
        XCTAssertEqual(insights.count, 0, "Should return empty for no data")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyEntriesReturnsEmptyData() {
        let entries: [FuelEntry] = []
        
        XCTAssertTrue(ChartDataService.efficiencyTrend(from: entries).isEmpty)
        XCTAssertTrue(ChartDataService.costPerKMTrend(from: entries).isEmpty)
        XCTAssertTrue(ChartDataService.driveModeComparison(from: entries).isEmpty)
        XCTAssertTrue(ChartDataService.aggregateMonthly(from: entries).isEmpty)
    }
    
    func testEntriesWithPartialDataHandledGracefully() {
        let entries = [
            FuelEntry(
                date: Date(),
                odometerStart: nil,
                odometerEnd: nil,
                totalLiters: 40,
                pricePerLiter: 1.50,
                gasStation: "Test"
            )
        ]
        
        XCTAssertTrue(ChartDataService.efficiencyTrend(from: entries).isEmpty)
        XCTAssertTrue(ChartDataService.costPerKMTrend(from: entries).isEmpty)
        
        // Monthly aggregation should still work
        let monthly = ChartDataService.aggregateMonthly(from: entries)
        XCTAssertEqual(monthly.count, 1)
        XCTAssertNil(monthly[0].averageEfficiency, "Should be nil without odometer")
    }
}
