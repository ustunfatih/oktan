import XCTest
@testable import oktan

/// Tests for the audit-hardening changes: CSV formula-injection escaping,
/// Keychain storage, and summary caching behavior.
@MainActor
final class AuditHardeningTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainStore.useInMemoryStoreForTesting()
    }

    // MARK: - CSV Escaping

    func testCSVEscapeNeutralizesFormulaPrefixes() {
        XCTAssertEqual(FuelRepository.csvEscape("=SUM(A1:A9)"), "'=SUM(A1:A9)")
        XCTAssertEqual(FuelRepository.csvEscape("+1234"), "'+1234")
        XCTAssertEqual(FuelRepository.csvEscape("-cmd"), "'-cmd")
        XCTAssertEqual(FuelRepository.csvEscape("@import"), "'@import")
    }

    func testCSVEscapeLeavesNormalTextAlone() {
        XCTAssertEqual(FuelRepository.csvEscape("Pearl"), "Pearl")
        XCTAssertEqual(FuelRepository.csvEscape("Wadi Al Banat"), "Wadi Al Banat")
        XCTAssertEqual(FuelRepository.csvEscape(""), "")
    }

    func testCSVEscapeReplacesDelimiter() {
        XCTAssertEqual(FuelRepository.csvEscape("Shell, Downtown"), "Shell; Downtown")
    }

    func testExportEscapesFormulaInStationName() {
        let repository = FuelRepository()
        for entry in repository.entries {
            repository.delete(entry)
        }
        let entry = FuelEntry(
            date: Date(),
            odometerStart: 100,
            odometerEnd: 200,
            totalLiters: 40,
            pricePerLiter: 2,
            gasStation: "=HYPERLINK(\"http://evil.example\")",
            driveMode: .normal,
            isFullRefill: true
        )
        XCTAssertTrue(repository.add(entry))
        let csv = repository.exportToCSV()
        XCTAssertTrue(csv.contains("'=HYPERLINK"))
        repository.delete(entry)
    }

    // MARK: - KeychainStore

    private struct Sample: Codable, Equatable {
        let id: String
        let value: Int
    }

    func testKeychainRoundTrip() {
        let key = "test-roundtrip-\(UUID().uuidString)"
        let sample = Sample(id: "abc", value: 42)

        XCTAssertTrue(KeychainStore.save(sample, forKey: key))
        XCTAssertEqual(KeychainStore.load(Sample.self, forKey: key), sample)

        XCTAssertTrue(KeychainStore.delete(forKey: key))
        XCTAssertNil(KeychainStore.load(Sample.self, forKey: key))
    }

    func testKeychainOverwrite() {
        let key = "test-overwrite-\(UUID().uuidString)"
        XCTAssertTrue(KeychainStore.save(Sample(id: "a", value: 1), forKey: key))
        XCTAssertTrue(KeychainStore.save(Sample(id: "b", value: 2), forKey: key))
        XCTAssertEqual(KeychainStore.load(Sample.self, forKey: key)?.id, "b")
        KeychainStore.delete(forKey: key)
    }

    func testKeychainDeleteMissingKeySucceeds() {
        XCTAssertTrue(KeychainStore.delete(forKey: "never-existed-\(UUID().uuidString)"))
    }

    // MARK: - Summary Caching

    func testSummaryReflectsMutationsDespiteCaching() {
        let repository = FuelRepository()
        for entry in repository.entries {
            repository.delete(entry)
        }

        XCTAssertEqual(repository.summary().totalCost, 0)

        let entry = FuelEntry(
            date: Date(),
            odometerStart: 0,
            odometerEnd: 100,
            totalLiters: 10,
            pricePerLiter: 2,
            gasStation: "Pearl",
            driveMode: .eco,
            isFullRefill: true
        )
        XCTAssertTrue(repository.add(entry))
        XCTAssertEqual(repository.summary().totalCost, 20, accuracy: 0.001)

        // Repeated call hits the cache and stays consistent
        XCTAssertEqual(repository.summary().totalCost, 20, accuracy: 0.001)

        repository.delete(entry)
        XCTAssertEqual(repository.summary().totalCost, 0)
    }
}
