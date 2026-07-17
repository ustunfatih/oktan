import XCTest
@testable import oktan

/// Tests for FuelEntry model and its computed properties
final class FuelEntryTests: XCTestCase {
    
    // MARK: - Distance Calculation Tests
    
    func testDistanceWithValidOdometerValues() {
        let entry = makeFuelEntry(odometerStart: 1000, odometerEnd: 1500)
        XCTAssertEqual(entry.distance, 500, "Distance should be 500 km")
    }
    
    func testDistanceWithNilOdometerStart() {
        let entry = makeFuelEntry(odometerStart: nil, odometerEnd: 1500)
        XCTAssertNil(entry.distance, "Distance should be nil when odometerStart is nil")
    }
    
    func testDistanceWithNilOdometerEnd() {
        let entry = makeFuelEntry(odometerStart: 1000, odometerEnd: nil)
        XCTAssertNil(entry.distance, "Distance should be nil when odometerEnd is nil")
    }
    
    func testDistanceWithBothOdometerNil() {
        let entry = makeFuelEntry(odometerStart: nil, odometerEnd: nil)
        XCTAssertNil(entry.distance, "Distance should be nil when both odometer values are nil")
    }
    
    func testDistanceWithInvalidOdometerValues() {
        // End is less than start - should return nil
        let entry = makeFuelEntry(odometerStart: 1500, odometerEnd: 1000)
        XCTAssertNil(entry.distance, "Distance should be nil when end < start")
    }
    
    func testDistanceWithEqualOdometerValues() {
        // Edge case: start == end
        let entry = makeFuelEntry(odometerStart: 1000, odometerEnd: 1000)
        XCTAssertNil(entry.distance, "Distance should be nil when start == end (not > start)")
    }
    
    // MARK: - Total Cost Tests
    
    func testTotalCostCalculation() {
        let entry = makeFuelEntry(totalLiters: 40.0, pricePerLiter: 2.05)
        XCTAssertEqual(entry.totalCost, 82.0, accuracy: 0.001, "Total cost should be 82.0")
    }
    
    func testTotalCostWithZeroLiters() {
        let entry = makeFuelEntry(totalLiters: 0, pricePerLiter: 2.05)
        XCTAssertEqual(entry.totalCost, 0, "Total cost should be 0 when liters is 0")
    }
    
    func testTotalCostWithZeroPrice() {
        let entry = makeFuelEntry(totalLiters: 40.0, pricePerLiter: 0)
        XCTAssertEqual(entry.totalCost, 0, "Total cost should be 0 when price is 0")
    }
    
    func testTotalCostPrecision() {
        // Test with values that could cause floating point issues
        let entry = makeFuelEntry(totalLiters: 41.46, pricePerLiter: 2.05)
        XCTAssertEqual(entry.totalCost, 84.993, accuracy: 0.001, "Total cost should be calculated with precision")
    }
    
    // MARK: - Liters Per 100KM Tests
    
    func testLitersPer100KMWithValidData() {
        // 40 liters over 400 km = 10 L/100km
        let entry = makeFuelEntry(
            odometerStart: 1000,
            odometerEnd: 1400,
            totalLiters: 40.0
        )
        XCTAssertEqual(entry.litersPer100KM ?? -1, 10.0, accuracy: 0.001, "L/100km should be 10.0")
    }
    
    func testLitersPer100KMWithRealWorldData() {
        // From seed data: 41.46 L over 414 km (170-584)
        let entry = makeFuelEntry(
            odometerStart: 170,
            odometerEnd: 584,
            totalLiters: 41.46
        )
        let expected = (41.46 / 414.0) * 100 // ≈ 10.01
        XCTAssertEqual(entry.litersPer100KM!, expected, accuracy: 0.001, "L/100km should match expected calculation")
    }
    
    func testLitersPer100KMWithNilDistance() {
        let entry = makeFuelEntry(
            odometerStart: nil,
            odometerEnd: nil,
            totalLiters: 40.0
        )
        XCTAssertNil(entry.litersPer100KM, "L/100km should be nil when distance is nil")
    }
    
    func testLitersPer100KMWithZeroDistance() {
        // Edge case that shouldn't happen in practice but guard against division by zero
        let entry = makeFuelEntry(
            odometerStart: 1000,
            odometerEnd: 1000,
            totalLiters: 40.0
        )
        XCTAssertNil(entry.litersPer100KM, "L/100km should be nil when distance is zero")
    }
    
    func testLitersPer100KMHighEfficiency() {
        // Very efficient: 30 L over 500 km = 6 L/100km
        let entry = makeFuelEntry(
            odometerStart: 0,
            odometerEnd: 500,
            totalLiters: 30.0
        )
        XCTAssertEqual(entry.litersPer100KM ?? -1, 6.0, accuracy: 0.001, "High efficiency should calculate correctly")
    }
    
    func testLitersPer100KMLowEfficiency() {
        // Less efficient: 60 L over 300 km = 20 L/100km
        let entry = makeFuelEntry(
            odometerStart: 0,
            odometerEnd: 300,
            totalLiters: 60.0
        )
        XCTAssertEqual(entry.litersPer100KM ?? -1, 20.0, accuracy: 0.001, "Low efficiency should calculate correctly")
    }
    
    // MARK: - Cost Per KM Tests
    
    func testCostPerKMWithValidData() {
        // 80 QAR over 400 km = 0.2 QAR/km
        let entry = makeFuelEntry(
            odometerStart: 1000,
            odometerEnd: 1400,
            totalLiters: 40.0,
            pricePerLiter: 2.0
        )
        XCTAssertEqual(entry.costPerKM ?? -1, 0.2, accuracy: 0.001, "Cost/km should be 0.2")
    }
    
    func testCostPerKMWithRealWorldData() {
        // From seed data: 41.46 L @ 2.05/L over 414 km
        let entry = makeFuelEntry(
            odometerStart: 170,
            odometerEnd: 584,
            totalLiters: 41.46,
            pricePerLiter: 2.05
        )
        let expectedCost = 41.46 * 2.05
        let expectedCostPerKM = expectedCost / 414.0
        XCTAssertEqual(entry.costPerKM!, expectedCostPerKM, accuracy: 0.001, "Cost/km should match expected calculation")
    }
    
    func testCostPerKMWithNilDistance() {
        let entry = makeFuelEntry(
            odometerStart: nil,
            odometerEnd: nil,
            totalLiters: 40.0,
            pricePerLiter: 2.0
        )
        XCTAssertNil(entry.costPerKM, "Cost/km should be nil when distance is nil")
    }
    
    // MARK: - Drive Mode Tests
    
    func testDriveModeEnumValues() {
        XCTAssertEqual(FuelEntry.DriveMode.eco.rawValue, "Eco")
        XCTAssertEqual(FuelEntry.DriveMode.normal.rawValue, "Normal")
        XCTAssertEqual(FuelEntry.DriveMode.sport.rawValue, "Sport")
    }
    
    func testDriveModeAllCases() {
        XCTAssertEqual(FuelEntry.DriveMode.allCases.count, 3)
    }
    
    // MARK: - Updating Odometer Tests
    
    func testUpdatingOdometerEnd() {
        let original = makeFuelEntry(odometerStart: 1000, odometerEnd: nil)
        let updated = original.updatingOdometer(end: 1500)
        
        XCTAssertEqual(updated.odometerEnd, 1500)
        XCTAssertEqual(updated.id, original.id, "ID should remain the same")
        XCTAssertEqual(updated.totalLiters, original.totalLiters, "Other properties should remain unchanged")
    }
    
    func testUpdatingOdometerEndToNil() {
        let original = makeFuelEntry(odometerStart: 1000, odometerEnd: 1500)
        let updated = original.updatingOdometer(end: nil)
        
        XCTAssertNil(updated.odometerEnd)
    }
    
    // MARK: - Equatable Tests
    
    func testEquatable() {
        let id = UUID()
        let date = Date()
        
        let entry1 = FuelEntry(
            id: id,
            date: date,
            odometerStart: 1000,
            odometerEnd: 1500,
            totalLiters: 40.0,
            pricePerLiter: 2.0,
            gasStation: "Pearl",
            driveMode: .normal,
            isFullRefill: true
        )
        
        let entry2 = FuelEntry(
            id: id,
            date: date,
            odometerStart: 1000,
            odometerEnd: 1500,
            totalLiters: 40.0,
            pricePerLiter: 2.0,
            gasStation: "Pearl",
            driveMode: .normal,
            isFullRefill: true
        )
        
        XCTAssertEqual(entry1, entry2)
    }
    
    // MARK: - Codable Tests
    
    func testEncodingAndDecoding() throws {
        let original = makeFuelEntry(
            odometerStart: 1000,
            odometerEnd: 1500,
            totalLiters: 40.0,
            pricePerLiter: 2.05
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FuelEntry.self, from: data)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.totalLiters, decoded.totalLiters)
        XCTAssertEqual(original.pricePerLiter, decoded.pricePerLiter)
        XCTAssertEqual(original.odometerStart, decoded.odometerStart)
        XCTAssertEqual(original.odometerEnd, decoded.odometerEnd)
    }
    
    // MARK: - Helper Methods
    
    private func makeFuelEntry(
        id: UUID = UUID(),
        date: Date = Date(),
        odometerStart: Double? = nil,
        odometerEnd: Double? = nil,
        totalLiters: Double = 40.0,
        pricePerLiter: Double = 2.0,
        gasStation: String = "Test Station",
        driveMode: FuelEntry.DriveMode = .normal,
        isFullRefill: Bool = true,
        notes: String? = nil
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
            isFullRefill: isFullRefill,
            notes: notes
        )
    }
}
