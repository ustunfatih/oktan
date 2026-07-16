import XCTest
@testable import oktan

/// Tests for phase 2 functionality: CSV round-trip mapping, next fill-up
/// prediction, and multi-car entry scoping.
@MainActor
final class CoreImprovementsTests: XCTestCase {

    // MARK: - CSV Round-Trip Mapping

    func testSuggestMappingHandlesOwnExportHeaders() {
        let headers = ["Date", "Odometer_Start", "Odometer_End", "Total_Liters", "Price_per_Liter",
                       "Total_Cost", "Full_Refill", "Drive_Mode", "Gas_Station", "Distance_KM",
                       "L_per_100KM", "Cost_per_KM", "Notes"]
        let mapping = CSVImportService.suggestMapping(for: headers)

        XCTAssertEqual(mapping.dateColumn, 0)
        XCTAssertEqual(mapping.odometerStartColumn, 1)
        XCTAssertEqual(mapping.odometerEndColumn, 2)
        XCTAssertEqual(mapping.litersColumn, 3)
        XCTAssertEqual(mapping.pricePerLiterColumn, 4)
        XCTAssertEqual(mapping.isFullRefillColumn, 6)
        XCTAssertEqual(mapping.driveModeColumn, 7)
        XCTAssertEqual(mapping.gasStationColumn, 8)
        XCTAssertEqual(mapping.notesColumn, 12)
    }

    func testSuggestMappingHandlesSampleCSVHeaders() {
        let headers = ["Date", "Odometer_Pre", "Odometer_Post", "Total_Litres", "Price_per_Litre",
                       "Total_Fuel_Cost", "Full_Depot", "Drive_Mode", "Gas_Station", "Total_Driven_KM",
                       "Used_Fuel_L", "Fuel_in_Tank_Pre", "Fuel_in_Tank_Post", "Calc_L_per_100KM", "Calc_Cost_per_KM"]
        let mapping = CSVImportService.suggestMapping(for: headers)

        XCTAssertEqual(mapping.dateColumn, 0)
        XCTAssertEqual(mapping.odometerStartColumn, 1)
        XCTAssertEqual(mapping.odometerEndColumn, 2)
        XCTAssertEqual(mapping.litersColumn, 3)
        XCTAssertEqual(mapping.pricePerLiterColumn, 4)
        XCTAssertEqual(mapping.isFullRefillColumn, 6)
        XCTAssertEqual(mapping.driveModeColumn, 7)
        XCTAssertEqual(mapping.gasStationColumn, 8)
    }

    func testDerivedColumnsDoNotStealCoreFields() {
        // "Cost_per_KM" and "L_per_100KM" contain "per"; they must not become
        // the price or liters column.
        let headers = ["Date", "Total_Liters", "Price_per_Liter", "L_per_100KM", "Cost_per_KM"]
        let mapping = CSVImportService.suggestMapping(for: headers)

        XCTAssertEqual(mapping.litersColumn, 1)
        XCTAssertEqual(mapping.pricePerLiterColumn, 2)
    }

    // MARK: - Next Fill-up Prediction

    private func makeEntry(daysAgo: Int, cost: Double = 80, now: Date) -> FuelEntry {
        FuelEntry(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!,
            odometerStart: nil,
            odometerEnd: nil,
            totalLiters: 40,
            pricePerLiter: cost / 40,
            gasStation: "Pearl",
            driveMode: .normal,
            isFullRefill: true
        )
    }

    func testPredictNextFillupUsesAverageInterval() {
        let now = Date()
        // Fill-ups every 10 days, last one 2 days ago -> next due in ~8 days
        let entries = [
            makeEntry(daysAgo: 22, now: now),
            makeEntry(daysAgo: 12, now: now),
            makeEntry(daysAgo: 2, now: now)
        ]

        let prediction = ChartDataService.predictNextFillup(from: entries, now: now)
        XCTAssertNotNil(prediction)

        let days = Calendar.current.dateComponents([.day], from: now, to: prediction!.date).day ?? -1
        XCTAssertTrue((6...8).contains(days), "Expected prediction ~8 days out, got \(days)")
        XCTAssertEqual(prediction!.estimatedCost ?? 0, 80, accuracy: 0.01)
    }

    func testPredictNextFillupClampsPastDatesToNow() {
        let now = Date()
        // Last fill-up 30 days ago with a 10-day interval -> already overdue
        let entries = [
            makeEntry(daysAgo: 50, now: now),
            makeEntry(daysAgo: 40, now: now),
            makeEntry(daysAgo: 30, now: now)
        ]

        let prediction = ChartDataService.predictNextFillup(from: entries, now: now)
        XCTAssertEqual(prediction?.date, now)
    }

    func testPredictNextFillupNeedsTwoEntries() {
        let now = Date()
        XCTAssertNil(ChartDataService.predictNextFillup(from: [makeEntry(daysAgo: 5, now: now)], now: now))
        XCTAssertNil(ChartDataService.predictNextFillup(from: [], now: now))
    }

    // MARK: - Multi-Car Scoping

    func testAddTagsEntryWithActiveCar() {
        let repository = FuelRepository()
        for entry in repository.entries { repository.delete(entry) }

        let carId = UUID()
        repository.activeCarId = carId

        let entry = makeEntry(daysAgo: 1, now: Date())
        XCTAssertTrue(repository.add(entry))
        XCTAssertEqual(repository.entries.first?.carId, carId)

        for entry in repository.entries { repository.delete(entry) }
    }

    func testVisibleEntriesFiltersByActiveCar() {
        let repository = FuelRepository()
        for entry in repository.entries { repository.delete(entry) }

        let carA = UUID()
        let carB = UUID()
        let now = Date()

        var entryA = makeEntry(daysAgo: 3, now: now)
        entryA.carId = carA
        var entryB = makeEntry(daysAgo: 2, now: now)
        entryB.carId = carB
        let legacy = makeEntry(daysAgo: 1, now: now) // carId == nil

        repository.activeCarId = nil
        XCTAssertTrue(repository.add(entryA))
        XCTAssertTrue(repository.add(entryB))
        XCTAssertTrue(repository.add(legacy))

        repository.activeCarId = carA
        let visible = repository.visibleEntries
        XCTAssertEqual(visible.count, 2) // carA entry + legacy nil entry
        XCTAssertTrue(visible.allSatisfy { $0.carId == carA || $0.carId == nil })

        repository.activeCarId = nil
        XCTAssertEqual(repository.visibleEntries.count, 3)

        for entry in repository.entries { repository.delete(entry) }
    }

    func testAssignOrphanEntriesAdoptsLegacyEntries() {
        let repository = FuelRepository()
        for entry in repository.entries { repository.delete(entry) }

        let carId = UUID()
        repository.activeCarId = nil
        XCTAssertTrue(repository.add(makeEntry(daysAgo: 1, now: Date())))

        repository.assignOrphanEntries(to: carId)
        XCTAssertTrue(repository.entries.allSatisfy { $0.carId == carId })

        for entry in repository.entries { repository.delete(entry) }
    }
}
