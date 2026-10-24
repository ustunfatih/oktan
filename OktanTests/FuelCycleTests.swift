import XCTest
@testable import oktan

/// Tests for tank-cycle efficiency, batched repository writes, RFC 4180 CSV
/// parsing, and locale-safe decimal input.
@MainActor
final class FuelCycleTests: XCTestCase {

    // MARK: - Fuel Cycles

    func testPartialRefillsAccumulateIntoNextFullRefill() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            makeEntry(date: base, start: 0, end: 300, liters: 20, full: false),
            makeEntry(date: base.addingTimeInterval(86_400), start: 300, end: 500, liters: 15, full: true)
        ]

        let cycles = FuelCycleService.completedCycles(from: entries)

        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles[0].id, entries[1].id)
        XCTAssertEqual(cycles[0].distance, 500, accuracy: 0.001)
        XCTAssertEqual(cycles[0].liters, 35, accuracy: 0.001)
        XCTAssertEqual(cycles[0].litersPer100KM, 7, accuracy: 0.001)
        XCTAssertEqual(cycles[0].entryCount, 2)
    }

    func testTrailingPartialRefillProducesNoCycle() {
        let entries = [makeEntry(date: Date(), start: 0, end: 300, liters: 20, full: false)]
        XCTAssertTrue(FuelCycleService.completedCycles(from: entries).isEmpty)
    }

    func testEntriesWithoutDistanceAreSkipped() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            makeEntry(date: base, start: nil, end: nil, liters: 50, full: true),
            makeEntry(date: base.addingTimeInterval(86_400), start: 0, end: 400, liters: 32, full: true)
        ]

        let cycles = FuelCycleService.completedCycles(from: entries)

        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles[0].litersPer100KM, 8, accuracy: 0.001)
    }

    func testCyclesAreOrderedByDateRegardlessOfInputOrder() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let later = makeEntry(date: base.addingTimeInterval(86_400), start: 400, end: 800, liters: 40, full: true)
        let earlier = makeEntry(date: base, start: 0, end: 400, liters: 20, full: true)

        let cycles = FuelCycleService.completedCycles(from: [later, earlier])

        XCTAssertEqual(cycles.map(\.id), [earlier.id, later.id])
    }

    // MARK: - Repository Batch Writes

    func testAddBatchAndDeleteAll() {
        let repository = FuelRepository()
        repository.deleteAll()

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let batch = (0..<3).map { index in
            makeEntry(
                date: base.addingTimeInterval(Double(index) * 86_400),
                start: Double(index) * 500,
                end: Double(index + 1) * 500,
                liters: 40,
                full: true
            )
        }

        XCTAssertTrue(repository.addBatch(batch))
        XCTAssertEqual(repository.entries.count, 3)

        XCTAssertTrue(repository.deleteAll())
        XCTAssertTrue(repository.entries.isEmpty)
    }

    func testAddBatchRejectsWholeBatchWhenOneEntryIsInvalid() {
        let repository = FuelRepository()
        repository.deleteAll()

        let valid = makeEntry(date: Date(), start: 0, end: 500, liters: 40, full: true)
        let invalid = makeEntry(date: Date(), start: 0, end: 500, liters: -1, full: true)

        XCTAssertFalse(repository.addBatch([valid, invalid]))
        XCTAssertTrue(repository.entries.isEmpty)
        XCTAssertNotNil(repository.lastError)
    }

    // MARK: - CSV Parsing

    func testParseCSVHandlesQuotedCommasEscapedQuotesAndNewlines() {
        let csv = "Date,Station,Notes\r\n2026-01-02,\"Shell, Doha\",\"Said \"\"hi\"\"\nsecond line\"\r\n\r\n2026-01-03,QP,\n"

        let result = CSVImportService.parseCSV(content: csv)

        XCTAssertEqual(result.headers, ["Date", "Station", "Notes"])
        XCTAssertEqual(result.rows, [
            ["2026-01-02", "Shell, Doha", "Said \"hi\"\nsecond line"],
            ["2026-01-03", "QP", ""]
        ])
    }

    func testParseCSVSplitsCRLFLines() {
        let csv = "Date,Liters\r\n2026-01-02,40\r\n2026-01-09,38\r\n"

        let result = CSVImportService.parseCSV(content: csv)

        XCTAssertEqual(result.headers, ["Date", "Liters"])
        XCTAssertEqual(result.rows, [["2026-01-02", "40"], ["2026-01-09", "38"]])
    }

    // MARK: - Decimal Input

    func testParseDecimalTreatsSingleSeparatorAsDecimalInEveryLocale() {
        for identifier in ["en", "tr", "de"] {
            let locale = Locale(identifier: identifier)
            XCTAssertEqual(FuelEntryFormView.parseDecimal("1.659", locale: locale), 1.659, identifier)
            XCTAssertEqual(FuelEntryFormView.parseDecimal("1,659", locale: locale), 1.659, identifier)
            XCTAssertEqual(FuelEntryFormView.parseDecimal(" 45 ", locale: locale), 45, identifier)
        }
    }

    func testParseDecimalUsesLocaleForGroupedInput() {
        XCTAssertEqual(FuelEntryFormView.parseDecimal("1.234,5", locale: Locale(identifier: "tr")), 1234.5)
        XCTAssertEqual(FuelEntryFormView.parseDecimal("1,234.5", locale: Locale(identifier: "en")), 1234.5)
        XCTAssertNil(FuelEntryFormView.parseDecimal("", locale: Locale(identifier: "en")))
    }

    // MARK: - Helpers

    private func makeEntry(date: Date, start: Double?, end: Double?, liters: Double, full: Bool) -> FuelEntry {
        FuelEntry(
            id: UUID(),
            date: date,
            odometerStart: start,
            odometerEnd: end,
            totalLiters: liters,
            pricePerLiter: 2.0,
            gasStation: "Test Station",
            driveMode: .normal,
            isFullRefill: full
        )
    }
}
