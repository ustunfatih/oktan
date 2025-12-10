import XCTest
@testable import Oktan

final class FuelEntryTests: XCTestCase {

    // MARK: - Distance Calculation

    func testDistance_withValidOdometerValues_returnsCorrectDistance() {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: 1000,
            odometerEnd: 1500,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        XCTAssertEqual(entry.distance, 500)
    }

    func testDistance_withNilOdometerStart_returnsNil() {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: nil,
            odometerEnd: 1500,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        XCTAssertNil(entry.distance)
    }

    func testDistance_withNilOdometerEnd_returnsNil() {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: 1000,
            odometerEnd: nil,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        XCTAssertNil(entry.distance)
    }

    func testDistance_withEqualOdometerValues_returnsNil() {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: 1000,
            odometerEnd: 1000,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        XCTAssertNil(entry.distance, "Distance should be nil when start equals end")
    }

    func testDistance_withEndLessThanStart_returnsNil() {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: 1500,
            odometerEnd: 1000,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        XCTAssertNil(entry.distance)
    }

    // MARK: - Total Cost

    func testTotalCost_calculatesCorrectly() {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: 1000,
            odometerEnd: 1500,
            totalLiters: 40,
            pricePerLiter: 2.05,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        XCTAssertEqual(entry.totalCost, 82.0, accuracy: 0.01)
    }

    // MARK: - Liters Per 100KM

    func testLitersPer100KM_withValidDistance_calculatesCorrectly() {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: 1000,
            odometerEnd: 1400,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        // 40L / 400km * 100 = 10 L/100km
        XCTAssertEqual(entry.litersPer100KM, 10.0, accuracy: 0.01)
    }

    func testLitersPer100KM_withNoDistance_returnsNil() {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: nil,
            odometerEnd: nil,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        XCTAssertNil(entry.litersPer100KM)
    }

    // MARK: - Cost Per KM

    func testCostPerKM_withValidDistance_calculatesCorrectly() {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: 1000,
            odometerEnd: 1400,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        // 80 QAR / 400km = 0.2 QAR/km
        XCTAssertEqual(entry.costPerKM, 0.2, accuracy: 0.001)
    }

    func testCostPerKM_withNoDistance_returnsNil() {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: nil,
            odometerEnd: nil,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        XCTAssertNil(entry.costPerKM)
    }

    // MARK: - Updating Odometer

    func testUpdatingOdometer_createsNewEntryWithUpdatedEnd() {
        let original = FuelEntry(
            date: Date(),
            odometerStart: 1000,
            odometerEnd: nil,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        let updated = original.updatingOdometer(end: 1500)

        XCTAssertEqual(updated.odometerEnd, 1500)
        XCTAssertEqual(updated.id, original.id)
        XCTAssertNil(original.odometerEnd, "Original should be unchanged")
    }
}
