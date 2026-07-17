import XCTest
@testable import oktan

/// Tests for FuelRepository - CRUD operations, validation, and summary calculations
@MainActor
final class FuelRepositoryTests: XCTestCase {
    
    var repository: FuelRepository!
    var tempDirectory: URL!
    
    override func setUp() async throws {
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create repository with a custom file manager pointing to temp directory
        repository = FuelRepository()
        
        // Clear any existing entries for clean tests
        // Note: In real implementation, we'd inject the storage URL
        for entry in repository.entries {
            repository.delete(entry)
        }
    }
    
    override func tearDown() async throws {
        // Clean up temp directory
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        repository = nil
    }
    
    // MARK: - Add Entry Tests
    
    func testAddValidEntry() {
        let entry = makeValidEntry()
        let result = repository.add(entry)
        
        XCTAssertTrue(result, "Adding valid entry should succeed")
        XCTAssertEqual(repository.entries.count, 1)
        XCTAssertEqual(repository.entries.first?.id, entry.id)
    }
    
    func testAddEntryWithZeroLiters() {
        let entry = makeEntry(totalLiters: 0)
        let result = repository.add(entry)
        
        XCTAssertFalse(result, "Adding entry with zero liters should fail")
        XCTAssertEqual(repository.entries.count, 0)
    }
    
    func testAddEntryWithNegativeLiters() {
        let entry = makeEntry(totalLiters: -10)
        let result = repository.add(entry)
        
        XCTAssertFalse(result, "Adding entry with negative liters should fail")
        XCTAssertEqual(repository.entries.count, 0)
    }
    
    func testAddEntryWithZeroPrice() {
        let entry = makeEntry(pricePerLiter: 0)
        let result = repository.add(entry)
        
        XCTAssertFalse(result, "Adding entry with zero price should fail")
        XCTAssertEqual(repository.entries.count, 0)
    }
    
    func testAddEntryWithNegativePrice() {
        let entry = makeEntry(pricePerLiter: -1)
        let result = repository.add(entry)
        
        XCTAssertFalse(result, "Adding entry with negative price should fail")
        XCTAssertEqual(repository.entries.count, 0)
    }
    
    func testAddEntryWithInvalidOdometer() {
        // End < Start should fail validation
        let entry = makeEntry(odometerStart: 1500, odometerEnd: 1000)
        let result = repository.add(entry)
        
        XCTAssertFalse(result, "Adding entry with end < start odometer should fail")
        XCTAssertEqual(repository.entries.count, 0)
    }
    
    func testAddEntryWithNilOdometerValues() {
        // Nil odometer values should be valid
        let entry = makeEntry(odometerStart: nil, odometerEnd: nil)
        let result = repository.add(entry)
        
        XCTAssertTrue(result, "Adding entry with nil odometer values should succeed")
        XCTAssertEqual(repository.entries.count, 1)
    }
    
    func testAddEntriesSortedByDate() {
        let oldDate = Date().addingTimeInterval(-86400 * 30) // 30 days ago
        let recentDate = Date()
        
        let recentEntry = makeEntry(date: recentDate)
        let oldEntry = makeEntry(date: oldDate)
        
        // Add in reverse chronological order
        repository.add(recentEntry)
        repository.add(oldEntry)
        
        // Should be sorted chronologically (oldest first)
        XCTAssertEqual(repository.entries.first?.id, oldEntry.id, "Older entry should be first")
        XCTAssertEqual(repository.entries.last?.id, recentEntry.id, "Recent entry should be last")
    }
    
    // MARK: - Update Entry Tests
    
    func testUpdateExistingEntry() {
        let entry = makeValidEntry()
        repository.add(entry)
        
        var updatedEntry = entry
        updatedEntry.gasStation = "Updated Station"
        
        repository.update(updatedEntry)
        
        XCTAssertEqual(repository.entries.first?.gasStation, "Updated Station")
    }
    
    func testUpdateNonExistingEntry() {
        let entry = makeValidEntry()
        repository.add(entry)
        
        let nonExistingEntry = makeEntry(id: UUID())
        repository.update(nonExistingEntry)
        
        // Should have no effect
        XCTAssertEqual(repository.entries.count, 1)
        XCTAssertEqual(repository.entries.first?.id, entry.id)
    }
    
    func testUpdateWithInvalidDataDoesNothing() {
        let entry = makeValidEntry()
        repository.add(entry)
        
        var invalidEntry = entry
        invalidEntry.totalLiters = 0 // Invalid
        
        repository.update(invalidEntry)
        
        // Should keep original value
        XCTAssertNotEqual(repository.entries.first?.totalLiters, 0)
    }
    
    // MARK: - Delete Entry Tests
    
    func testDeleteEntry() {
        let entry = makeValidEntry()
        repository.add(entry)
        
        repository.delete(entry)
        
        XCTAssertEqual(repository.entries.count, 0)
    }
    
    func testDeleteNonExistingEntry() {
        let entry = makeValidEntry()
        repository.add(entry)
        
        let nonExistingEntry = makeEntry(id: UUID())
        repository.delete(nonExistingEntry)
        
        // Should have no effect
        XCTAssertEqual(repository.entries.count, 1)
    }
    
    // MARK: - Summary Tests
    
    func testSummaryWithNoEntries() {
        let summary = repository.summary()
        
        XCTAssertEqual(summary.totalDistance, 0)
        XCTAssertEqual(summary.totalLiters, 0)
        XCTAssertEqual(summary.totalCost, 0)
        XCTAssertNil(summary.averageLitersPer100KM)
        XCTAssertNil(summary.averageCostPerKM)
    }
    
    func testSummaryTotalDistance() {
        // Add entries with known distances
        let entry1 = makeEntry(odometerStart: 0, odometerEnd: 100, totalLiters: 10)
        let entry2 = makeEntry(odometerStart: 100, odometerEnd: 300, totalLiters: 20)
        
        repository.add(entry1)
        repository.add(entry2)
        
        let summary = repository.summary()
        
        // 100 + 200 = 300 km
        XCTAssertEqual(summary.totalDistance, 300, accuracy: 0.001)
    }
    
    func testSummaryTotalLiters() {
        let entry1 = makeEntry(odometerStart: 0, odometerEnd: 100, totalLiters: 10)
        let entry2 = makeEntry(odometerStart: 100, odometerEnd: 200, totalLiters: 15)
        
        repository.add(entry1)
        repository.add(entry2)
        
        let summary = repository.summary()
        
        // Only completed entries (with distance) count
        XCTAssertEqual(summary.totalLiters, 25, accuracy: 0.001)
    }
    
    func testSummaryTotalCost() {
        let entry1 = makeEntry(odometerStart: 0, odometerEnd: 100, totalLiters: 10, pricePerLiter: 2.0)
        let entry2 = makeEntry(odometerStart: 100, odometerEnd: 200, totalLiters: 20, pricePerLiter: 2.5)
        
        repository.add(entry1)
        repository.add(entry2)
        
        let summary = repository.summary()
        
        // 10*2 + 20*2.5 = 20 + 50 = 70
        XCTAssertEqual(summary.totalCost, 70, accuracy: 0.001)
    }
    
    func testSummaryAverageLitersPer100KM() {
        // 40 liters over 400 km = 10 L/100km average
        let entry = makeEntry(odometerStart: 0, odometerEnd: 400, totalLiters: 40)
        repository.add(entry)
        
        let summary = repository.summary()
        
        XCTAssertEqual(summary.averageLitersPer100KM!, 10.0, accuracy: 0.001)
    }
    
    func testSummaryAverageCostPerKM() {
        // 80 QAR over 400 km = 0.2 QAR/km
        let entry = makeEntry(odometerStart: 0, odometerEnd: 400, totalLiters: 40, pricePerLiter: 2.0)
        repository.add(entry)
        
        let summary = repository.summary()
        
        XCTAssertEqual(summary.averageCostPerKM!, 0.2, accuracy: 0.001)
    }
    
    func testSummaryExcludesEntriesWithoutDistance() {
        // Entry with distance
        let completeEntry = makeEntry(odometerStart: 0, odometerEnd: 100, totalLiters: 10)
        // Entry without distance
        let incompleteEntry = makeEntry(odometerStart: nil, odometerEnd: nil, totalLiters: 50)
        
        repository.add(completeEntry)
        repository.add(incompleteEntry)
        
        let summary = repository.summary()
        
        // Only complete entry should count for distance/liters calculations
        XCTAssertEqual(summary.totalDistance, 100, accuracy: 0.001)
        XCTAssertEqual(summary.totalLiters, 10, accuracy: 0.001)
    }
    
    func testSummaryRecentAverageWithLessThan5Entries() {
        let entry1 = makeEntry(odometerStart: 0, odometerEnd: 100, totalLiters: 10)
        let entry2 = makeEntry(odometerStart: 100, odometerEnd: 200, totalLiters: 12)
        
        repository.add(entry1)
        repository.add(entry2)
        
        let summary = repository.summary()
        
        // Should use available entries for recent average
        XCTAssertNotNil(summary.recentAverageLitersPer100KM)
    }
    
    func testSummaryDriveModeBreakdown() {
        let ecoEntry = makeEntry(odometerStart: 0, odometerEnd: 100, totalLiters: 8, driveMode: .eco)
        let sportEntry = makeEntry(odometerStart: 100, odometerEnd: 200, totalLiters: 15, driveMode: .sport)
        
        repository.add(ecoEntry)
        repository.add(sportEntry)
        
        let summary = repository.summary()
        
        XCTAssertNotNil(summary.driveModeBreakdown[.eco])
        XCTAssertNotNil(summary.driveModeBreakdown[.sport])
        XCTAssertNil(summary.driveModeBreakdown[.normal])
        
        // Eco: 8L/100km
        XCTAssertEqual(summary.driveModeBreakdown[.eco]?.lPer100KM ?? -1, 8.0, accuracy: 0.001)
        // Sport: 15L/100km
        XCTAssertEqual(summary.driveModeBreakdown[.sport]?.lPer100KM ?? -1, 15.0, accuracy: 0.001)
    }
    
    // MARK: - CSV Export Tests
    
    func testExportToCSVHeader() {
        let csv = repository.exportToCSV()
        
        XCTAssertTrue(csv.hasPrefix("Date,Odometer_Start,Odometer_End"))
        XCTAssertTrue(csv.contains("L_per_100KM"))
        XCTAssertTrue(csv.contains("Cost_per_KM"))
    }
    
    func testExportToCSVWithEntries() {
        let entry = makeEntry(
            odometerStart: 1000,
            odometerEnd: 1500,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Pearl"
        )
        repository.add(entry)
        
        let csv = repository.exportToCSV()
        let lines = csv.components(separatedBy: "\n")
        
        XCTAssertEqual(lines.count, 3) // Header + 1 entry + empty line at end
        XCTAssertTrue(lines[1].contains("Pearl"))
        XCTAssertTrue(lines[1].contains("40.00"))
    }
    
    func testExportToCSVHandlesCommasInGasStation() {
        let entry = makeEntry(gasStation: "Gas, Station, Name")
        repository.add(entry)
        
        let csv = repository.exportToCSV()
        
        // Commas in station name should be replaced with semicolons
        XCTAssertTrue(csv.contains("Gas; Station; Name"))
    }
    
    // MARK: - Accuracy Verification Tests (Critical for Phase 5)
    
    func testRealWorldDataAccuracy() {
        // Using actual seed data to verify calculations
        let entries = [
            makeEntry(odometerStart: 170, odometerEnd: 584, totalLiters: 41.46, pricePerLiter: 2.05, driveMode: .eco),
            makeEntry(odometerStart: 584, odometerEnd: 963, totalLiters: 41.03, pricePerLiter: 1.95, driveMode: .normal),
            makeEntry(odometerStart: 963, odometerEnd: 1364, totalLiters: 41.04, pricePerLiter: 1.95, driveMode: .normal)
        ]
        
        for entry in entries {
            repository.add(entry)
        }
        
        let summary = repository.summary()
        
        // Verify total distance: (584-170) + (963-584) + (1364-963) = 414 + 379 + 401 = 1194
        XCTAssertEqual(summary.totalDistance, 1194, accuracy: 0.001, "Total distance calculation must be accurate")
        
        // Verify total liters: 41.46 + 41.03 + 41.04 = 123.53
        XCTAssertEqual(summary.totalLiters, 123.53, accuracy: 0.001, "Total liters calculation must be accurate")
        
        // Verify total cost: (41.46*2.05) + (41.03*1.95) + (41.04*1.95) = 84.993 + 80.0085 + 80.028 = 245.0295
        let expectedCost = (41.46 * 2.05) + (41.03 * 1.95) + (41.04 * 1.95)
        XCTAssertEqual(summary.totalCost, expectedCost, accuracy: 0.01, "Total cost calculation must be accurate")
        
        // Verify average L/100km: 123.53 / 1194 * 100 = 10.346...
        let expectedLPer100 = (123.53 / 1194.0) * 100
        XCTAssertEqual(summary.averageLitersPer100KM!, expectedLPer100, accuracy: 0.01, "Average L/100km must be accurate")
    }
    
    // MARK: - Helper Methods
    
    private func makeValidEntry() -> FuelEntry {
        makeEntry(odometerStart: 1000, odometerEnd: 1500, totalLiters: 40, pricePerLiter: 2.0)
    }
    
    private func makeEntry(
        id: UUID = UUID(),
        date: Date = Date(),
        odometerStart: Double? = 1000,
        odometerEnd: Double? = 1500,
        totalLiters: Double = 40.0,
        pricePerLiter: Double = 2.0,
        gasStation: String = "Test Station",
        driveMode: FuelEntry.DriveMode = .normal,
        isFullRefill: Bool = true
    ) -> FuelEntry {
        FuelEntry(
            id: id,
            date: date,
            odometerStart: odometerStart,
            odometerEnd: odometerEnd,
            totalLiters: totalLiters,
            pricePerLiter: pricePerLiter,
            gasStation: gasStation,
            driveMode: driveMode,
            isFullRefill: isFullRefill
        )
    }
}
