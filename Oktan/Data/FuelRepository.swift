import Foundation
import Combine
import SwiftData

@MainActor
final class FuelRepository: ObservableObject {
    @Published private(set) var entries: [FuelEntry] = []

    /// Last error that occurred (for UI display)
    @Published private(set) var lastError: OktanError?

    /// Cached summary, invalidated whenever entries change.
    /// Views call summary() from body, so recomputing on every render is wasted work.
    private var cachedSummary: FuelSummary?
    
    // MARK: - Storage Mode
    
    private enum StorageMode {
        case json(url: URL, encoder: JSONEncoder, decoder: JSONDecoder)
        case swiftData(context: ModelContext)
    }
    
    private let storageMode: StorageMode
    
    // MARK: - Initialization
    
    /// Legacy JSON-based initialization
    init(fileManager: FileManager = .default) {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let storageURL = directory.appendingPathComponent("fuel_entries.json")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        self.storageMode = .json(url: storageURL, encoder: encoder, decoder: decoder)
    }
    
    /// SwiftData-based initialization
    init(modelContext: ModelContext) {
        self.storageMode = .swiftData(context: modelContext)
    }
    
    /// Clears the last error
    func clearError() {
        lastError = nil
    }

    func bootstrapIfNeeded() {
        loadEntries()
        if entries.isEmpty {
            for entry in SeedData.entries {
                _ = add(entry)
            }
        }
    }

    @discardableResult
    func add(_ entry: FuelEntry) -> Bool {
        // Validate entry
        if let validationError = validateWithError(entry) {
            lastError = validationError
            return false
        }
        
        switch storageMode {
        case .swiftData(let context):
            let sdEntry = FuelEntrySD(from: entry)
            context.insert(sdEntry)
            do {
                try context.save()
            } catch {
                lastError = .saveFailed(reason: error.localizedDescription)
                return false
            }
        case .json:
            break
        }
        
        entries.append(entry)
        entries.sort { $0.date < $1.date }
        cachedSummary = nil
        persistIfJSON()
        return true
    }

    func update(_ entry: FuelEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }), validate(entry) else { return }
        
        switch storageMode {
        case .swiftData(let context):
            let descriptor = FetchDescriptor<FuelEntrySD>(
                predicate: #Predicate { $0.entryId == entry.id }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.update(from: entry)
                try? context.save()
            }
        case .json:
            break
        }
        
        entries[index] = entry
        entries.sort { $0.date < $1.date }
        cachedSummary = nil
        persistIfJSON()
    }

    func delete(_ entry: FuelEntry) {
        switch storageMode {
        case .swiftData(let context):
            let descriptor = FetchDescriptor<FuelEntrySD>(
                predicate: #Predicate { $0.entryId == entry.id }
            )
            if let existing = try? context.fetch(descriptor).first {
                context.delete(existing)
                try? context.save()
            }
        case .json:
            break
        }
        
        entries.removeAll { $0.id == entry.id }
        cachedSummary = nil
        persistIfJSON()
    }

    func summary() -> FuelSummary {
        if let cachedSummary {
            return cachedSummary
        }
        let completed = entries.compactMap { entry -> FuelEntry? in
            guard entry.distance != nil else { return nil }
            return entry
        }

        let distance = completed.compactMap { $0.distance }.reduce(0, +)
        let liters = completed.reduce(0) { $0 + $1.totalLiters }
        let cost = completed.reduce(0) { $0 + $1.totalCost }

        let lPer100 = distance > 0 ? (liters / distance) * 100 : nil
        let costPerKM = distance > 0 ? cost / distance : nil

        let recent = completed.suffix(5)
        let recentLPer100 = recent.compactMap { $0.litersPer100KM }.average()
        let recentCostPerKM = recent.compactMap { $0.costPerKM }.average()

        let modes = Dictionary(grouping: completed, by: { $0.driveMode })
            .mapValues { group -> DriveModeBreakdown in
                let modeDistance = group.compactMap { $0.distance }.reduce(0, +)
                let modeLiters = group.reduce(0) { $0 + $1.totalLiters }
                let modeCost = group.reduce(0) { $0 + $1.totalCost }

                let lPer100 = modeDistance > 0 ? (modeLiters / modeDistance) * 100 : nil
                let costPerKM = modeDistance > 0 ? modeCost / modeDistance : nil
                return DriveModeBreakdown(distance: modeDistance, lPer100KM: lPer100, costPerKM: costPerKM)
            }

        let result = FuelSummary(
            totalDistance: distance,
            totalLiters: liters,
            totalCost: cost,
            averageLitersPer100KM: lPer100,
            averageCostPerKM: costPerKM,
            recentAverageLitersPer100KM: recentLPer100,
            recentAverageCostPerKM: recentCostPerKM,
            driveModeBreakdown: modes
        )
        cachedSummary = result
        return result
    }

    private func validate(_ entry: FuelEntry) -> Bool {
        validateWithError(entry) == nil
    }
    
    /// Validates an entry and returns a specific error if invalid
    private func validateWithError(_ entry: FuelEntry) -> OktanError? {
        if entry.totalLiters <= 0 {
            return .validationFailed(field: "Total Liters", reason: "Must be greater than zero")
        }
        if entry.pricePerLiter <= 0 {
            return .validationFailed(field: "Price per Liter", reason: "Must be greater than zero")
        }
        if let start = entry.odometerStart, let end = entry.odometerEnd, end < start {
            return .validationFailed(field: "Odometer", reason: "End reading must be greater than start")
        }
        return nil
    }

    /// Loads entries based on storage mode
    private func loadEntries() {
        switch storageMode {
        case .json(let url, _, let decoder):
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? decoder.decode([FuelEntry].self, from: data) else {
                return
            }
            entries = decoded
            cachedSummary = nil

        case .swiftData(let context):
            let descriptor = FetchDescriptor<FuelEntrySD>(
                sortBy: [SortDescriptor(\.date)]
            )
            do {
                let sdEntries = try context.fetch(descriptor)
                entries = sdEntries.map { $0.toFuelEntry() }
                cachedSummary = nil
            } catch {
                print("Failed to load entries: \(error)")
            }
        }
    }
    
    /// Persists to disk only if using JSON storage
    private func persistIfJSON() {
        guard case .json(let url, let encoder, _) = storageMode else { return }
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - CSV Export

    /// Escapes a free-text CSV field: strips the delimiter and neutralizes
    /// leading characters that spreadsheet apps would interpret as formulas.
    static func csvEscape(_ field: String) -> String {
        var escaped = field.replacingOccurrences(of: ",", with: ";")
        if let first = escaped.first, "=+-@".contains(first) {
            escaped = "'" + escaped
        }
        return escaped
    }

    /// Exports all entries to CSV format
    func exportToCSV() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var csv = "Date,Odometer_Start,Odometer_End,Total_Liters,Price_per_Liter,Total_Cost,Full_Refill,Drive_Mode,Gas_Station,Distance_KM,L_per_100KM,Cost_per_KM,Notes\n"

        for entry in entries.sorted(by: { $0.date < $1.date }) {
            let date = dateFormatter.string(from: entry.date)
            let odometerStart = entry.odometerStart.map { String(format: "%.0f", $0) } ?? ""
            let odometerEnd = entry.odometerEnd.map { String(format: "%.0f", $0) } ?? ""
            let liters = String(format: "%.2f", entry.totalLiters)
            let price = String(format: "%.2f", entry.pricePerLiter)
            let totalCost = String(format: "%.2f", entry.totalCost)
            let fullRefill = entry.isFullRefill ? "true" : "false"
            let driveMode = entry.driveMode.rawValue
            let station = Self.csvEscape(entry.gasStation)
            let distance = entry.distance.map { String(format: "%.0f", $0) } ?? ""
            let lPer100 = entry.litersPer100KM.map { String(format: "%.2f", $0) } ?? ""
            let costPerKM = entry.costPerKM.map { String(format: "%.3f", $0) } ?? ""
            let notes = Self.csvEscape(entry.notes ?? "")

            csv += "\(date),\(odometerStart),\(odometerEnd),\(liters),\(price),\(totalCost),\(fullRefill),\(driveMode),\(station),\(distance),\(lPer100),\(costPerKM),\(notes)\n"
        }

        return csv
    }

    /// Creates a shareable CSV file URL
    func createCSVFile() -> URL? {
        let csv = exportToCSV()
        let fileName = "oktan-fuel-log-\(Date().formatted(.iso8601.year().month().day())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }
}

struct FuelSummary {
    let totalDistance: Double
    let totalLiters: Double
    let totalCost: Double
    let averageLitersPer100KM: Double?
    let averageCostPerKM: Double?
    let recentAverageLitersPer100KM: Double?
    let recentAverageCostPerKM: Double?
    let driveModeBreakdown: [FuelEntry.DriveMode: DriveModeBreakdown]
}

struct DriveModeBreakdown {
    let distance: Double
    let lPer100KM: Double?
    let costPerKM: Double?
}

enum SeedData {
    static var entries: [FuelEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let raw: [(String, Double?, Double?, Double, Double, String, FuelEntry.DriveMode, Bool)] = [
            ("16/04/2025", 13, 170, 19.58, 2.05, "Unknown", .normal, false),
            ("28/04/2025", 170, 584, 41.46, 2.05, "Pearl", .eco, true),
            ("12/05/2025", 584, 963, 41.03, 1.95, "Pearl", .normal, true),
            ("31/05/2025", 963, 1364, 41.04, 1.95, "Pearl", .normal, true),
            ("06/07/2025", 1364, 1773, 40.86, 2.0, "Onaiza", .normal, true),
            ("20/07/2025", 1773, 2130, 42.57, 2.0, "Pearl", .sport, true),
            ("10/09/2025", 2130, 2503, 41.01, 2.0, "Pearl", .sport, true),
            ("11/10/2025", 2503, 2922, 42.94, 2.05, "Pearl", .normal, true),
            ("27/10/2025", 2922, 3334, 41.95, 2.05, "Pearl", .normal, true),
            ("19/11/2025", 3334, 3762, 44.5, 2.0, "Pearl", .eco, true),
            ("06/12/2025", 3762, nil, 42.93, 2.05, "Wadi Al Banat", .eco, true)
        ]

        return raw.compactMap { tuple in
            guard let date = formatter.date(from: tuple.0) else { return nil }
            return FuelEntry(
                date: date,
                odometerStart: tuple.1,
                odometerEnd: tuple.2,
                totalLiters: tuple.3,
                pricePerLiter: tuple.4,
                gasStation: tuple.5,
                driveMode: tuple.6,
                isFullRefill: tuple.7
            )
        }
    }
}

private extension Array where Element == Double {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
