import XCTest
@testable import Oktan

@MainActor
final class FuelRepositoryTests: XCTestCase {

    private var repository: FuelRepository!

    override func setUp() async throws {
        repository = FuelRepository()
    }

    override func tearDown() async throws {
        repository = nil
    }

    // MARK: - Add Entry

    func testAdd_withValidEntry_returnsTrue() async {
        let entry = makeEntry(liters: 40, pricePerLiter: 2.0)

        let result = repository.add(entry)

        XCTAssertTrue(result)
        XCTAssertEqual(repository.entries.count, 1)
    }

    func testAdd_withZeroLiters_returnsFalse() async {
        let entry = makeEntry(liters: 0, pricePerLiter: 2.0)

        let result = repository.add(entry)

        XCTAssertFalse(result)
        XCTAssertEqual(repository.entries.count, 0)
    }

    func testAdd_withNegativeLiters_returnsFalse() async {
        let entry = makeEntry(liters: -10, pricePerLiter: 2.0)

        let result = repository.add(entry)

        XCTAssertFalse(result)
    }

    func testAdd_withZeroPrice_returnsFalse() async {
        let entry = makeEntry(liters: 40, pricePerLiter: 0)

        let result = repository.add(entry)

        XCTAssertFalse(result)
    }

    func testAdd_withInvalidOdometer_returnsFalse() async {
        let entry = FuelEntry(
            date: Date(),
            odometerStart: 1500,
            odometerEnd: 1000, // End < Start is invalid
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )

        let result = repository.add(entry)

        XCTAssertFalse(result)
    }

    func testAdd_sortsEntriesByDate() async {
        let olderEntry = makeEntry(date: Date().addingTimeInterval(-86400), liters: 30, pricePerLiter: 2.0)
        let newerEntry = makeEntry(date: Date(), liters: 40, pricePerLiter: 2.0)

        repository.add(newerEntry)
        repository.add(olderEntry)

        XCTAssertEqual(repository.entries.first?.totalLiters, 30)
        XCTAssertEqual(repository.entries.last?.totalLiters, 40)
    }

    // MARK: - Delete Entry

    func testDelete_removesEntry() async {
        let entry = makeEntry(liters: 40, pricePerLiter: 2.0)
        repository.add(entry)

        repository.delete(entry)

        XCTAssertEqual(repository.entries.count, 0)
    }

    func testDelete_withNonexistentEntry_doesNothing() async {
        let entry1 = makeEntry(liters: 40, pricePerLiter: 2.0)
        let entry2 = makeEntry(liters: 30, pricePerLiter: 2.0)
        repository.add(entry1)

        repository.delete(entry2)

        XCTAssertEqual(repository.entries.count, 1)
    }

    // MARK: - Update Entry

    func testUpdate_modifiesExistingEntry() async {
        var entry = makeEntry(liters: 40, pricePerLiter: 2.0)
        repository.add(entry)

        entry.gasStation = "Updated Station"
        repository.update(entry)

        XCTAssertEqual(repository.entries.first?.gasStation, "Updated Station")
    }

    func testUpdate_withInvalidData_doesNotModify() async {
        var entry = makeEntry(liters: 40, pricePerLiter: 2.0)
        repository.add(entry)
        let originalStation = entry.gasStation

        entry.totalLiters = 0 // Invalid
        entry.gasStation = "Updated Station"
        repository.update(entry)

        XCTAssertEqual(repository.entries.first?.gasStation, originalStation)
    }

    // MARK: - Summary

    func testSummary_calculatesTotalsCorrectly() async {
        let entry1 = FuelEntry(
            date: Date(),
            odometerStart: 1000,
            odometerEnd: 1400,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )
        let entry2 = FuelEntry(
            date: Date().addingTimeInterval(86400),
            odometerStart: 1400,
            odometerEnd: 1800,
            totalLiters: 42,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .eco,
            isFullRefill: true
        )
        repository.add(entry1)
        repository.add(entry2)

        let summary = repository.summary()

        XCTAssertEqual(summary.totalDistance, 800, accuracy: 0.01)
        XCTAssertEqual(summary.totalLiters, 82, accuracy: 0.01)
        XCTAssertEqual(summary.totalCost, 164, accuracy: 0.01)
    }

    func testSummary_excludesEntriesWithoutDistance() async {
        let completeEntry = FuelEntry(
            date: Date(),
            odometerStart: 1000,
            odometerEnd: 1400,
            totalLiters: 40,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .normal,
            isFullRefill: true
        )
        let incompleteEntry = FuelEntry(
            date: Date().addingTimeInterval(86400),
            odometerStart: 1400,
            odometerEnd: nil, // Missing end
            totalLiters: 42,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .eco,
            isFullRefill: true
        )
        repository.add(completeEntry)
        repository.add(incompleteEntry)

        let summary = repository.summary()

        XCTAssertEqual(summary.totalDistance, 400, accuracy: 0.01)
        XCTAssertEqual(summary.totalLiters, 40, accuracy: 0.01)
    }

    func testSummary_calculatesDriveModeBreakdown() async {
        let ecoEntry = FuelEntry(
            date: Date(),
            odometerStart: 1000,
            odometerEnd: 1400,
            totalLiters: 36,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .eco,
            isFullRefill: true
        )
        let sportEntry = FuelEntry(
            date: Date().addingTimeInterval(86400),
            odometerStart: 1400,
            odometerEnd: 1800,
            totalLiters: 48,
            pricePerLiter: 2.0,
            gasStation: "Test",
            driveMode: .sport,
            isFullRefill: true
        )
        repository.add(ecoEntry)
        repository.add(sportEntry)

        let summary = repository.summary()

        // Eco: 36L / 400km * 100 = 9 L/100km
        XCTAssertEqual(summary.driveModeBreakdown[.eco]?.lPer100KM, 9.0, accuracy: 0.01)
        // Sport: 48L / 400km * 100 = 12 L/100km
        XCTAssertEqual(summary.driveModeBreakdown[.sport]?.lPer100KM, 12.0, accuracy: 0.01)
    }

    // MARK: - Helpers

    private func makeEntry(
        date: Date = Date(),
        liters: Double,
        pricePerLiter: Double
    ) -> FuelEntry {
        FuelEntry(
            date: date,
            odometerStart: nil,
            odometerEnd: nil,
            totalLiters: liters,
            pricePerLiter: pricePerLiter,
            gasStation: "Test Station",
            driveMode: .normal,
            isFullRefill: true
        )
    }
}
