import Foundation
import Combine
import SwiftData
import WidgetKit

@MainActor
final class FuelRepository: ObservableObject {
    @Published private(set) var entries: [FuelEntry] = []

    /// Last error that occurred (for UI display)
    @Published private(set) var lastError: OktanError?

    /// Cached summary, invalidated whenever entries change.
    /// Views call summary() from body, so recomputing on every render is wasted work.
    private var cachedSummary: FuelSummary?

    /// The car whose entries are shown. nil = all cars.
    @Published var activeCarId: UUID? {
        didSet { cachedSummary = nil }
    }

    /// Entries for the active car, kept sorted by date ascending.
    /// Entries without a carId predate multi-car support and are always shown.
    var visibleEntries: [FuelEntry] {
        guard let activeCarId else { return entries }
        return entries.filter { $0.carId == activeCarId || $0.carId == nil }
    }
    
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
    }

    /// One-time adoption of legacy entries (no carId) by the given car.
    func assignOrphanEntries(to carId: UUID) {
        let orphans = entries.filter { $0.carId == nil }
        for var entry in orphans {
            entry.carId = carId
            update(entry)
        }
    }

    @discardableResult
    func add(_ entry: FuelEntry) -> Bool {
        var entry = entry
        // New entries belong to the active car unless explicitly tagged.
        if entry.carId == nil {
            entry.carId = activeCarId
        }

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
                context.rollback()
                lastError = .saveFailed(reason: error.localizedDescription)
                return false
            }
        case .json:
            break
        }
        
        entries.append(entry)
        entries.sort { $0.date < $1.date }
        cachedSummary = nil
        guard persistIfJSON() else {
            entries.removeAll { $0.id == entry.id }
            cachedSummary = nil
            return false
        }
        reloadWidget()
        return true
    }

    /// Inserts an import as one transaction so large CSV files do not save once per row.
    @discardableResult
    func addBatch(_ newEntries: [FuelEntry]) -> Bool {
        guard !newEntries.isEmpty else { return true }

        var preparedEntries = newEntries
        for index in preparedEntries.indices {
            if preparedEntries[index].carId == nil {
                preparedEntries[index].carId = activeCarId
            }
            if let validationError = validateWithError(preparedEntries[index]) {
                lastError = validationError
                return false
            }
        }

        switch storageMode {
        case .swiftData(let context):
            for entry in preparedEntries {
                context.insert(FuelEntrySD(from: entry))
            }
            do {
                try context.save()
            } catch {
                context.rollback()
                lastError = .saveFailed(reason: error.localizedDescription)
                return false
            }
        case .json:
            let previousEntries = entries
            entries.append(contentsOf: preparedEntries)
            entries.sort { $0.date < $1.date }
            cachedSummary = nil
            guard persistIfJSON() else {
                entries = previousEntries
                cachedSummary = nil
                return false
            }
            reloadWidget()
            return true
        }

        entries.append(contentsOf: preparedEntries)
        entries.sort { $0.date < $1.date }
        cachedSummary = nil
        reloadWidget()
        return true
    }

    @discardableResult
    func update(_ entry: FuelEntry) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            lastError = .saveFailed(reason: "The entry no longer exists")
            return false
        }
        if let validationError = validateWithError(entry) {
            lastError = validationError
            return false
        }
        
        switch storageMode {
        case .swiftData(let context):
            let descriptor = FetchDescriptor<FuelEntrySD>(
                predicate: #Predicate { $0.entryId == entry.id }
            )
            do {
                guard let existing = try context.fetch(descriptor).first else {
                    lastError = .saveFailed(reason: "The entry no longer exists")
                    return false
                }
                existing.update(from: entry)
                try context.save()
            } catch {
                context.rollback()
                lastError = .saveFailed(reason: error.localizedDescription)
                return false
            }
        case .json:
            let previous = entries[index]
            entries[index] = entry
            entries.sort { $0.date < $1.date }
            cachedSummary = nil
            guard persistIfJSON() else {
                if let updatedIndex = entries.firstIndex(where: { $0.id == previous.id }) {
                    entries[updatedIndex] = previous
                    entries.sort { $0.date < $1.date }
                }
                cachedSummary = nil
                return false
            }
            reloadWidget()
            return true
        }
        
        entries[index] = entry
        entries.sort { $0.date < $1.date }
        cachedSummary = nil
        reloadWidget()
        return true
    }

    @discardableResult
    func delete(_ entry: FuelEntry) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            lastError = .deleteFailed(reason: "The entry no longer exists")
            return false
        }

        switch storageMode {
        case .swiftData(let context):
            let descriptor = FetchDescriptor<FuelEntrySD>(
                predicate: #Predicate { $0.entryId == entry.id }
            )
            do {
                guard let existing = try context.fetch(descriptor).first else {
                    lastError = .deleteFailed(reason: "The entry no longer exists")
                    return false
                }
                context.delete(existing)
                try context.save()
            } catch {
                context.rollback()
                lastError = .deleteFailed(reason: error.localizedDescription)
                return false
            }
        case .json:
            entries.remove(at: index)
            cachedSummary = nil
            guard persistIfJSON() else {
                entries.append(entry)
                entries.sort { $0.date < $1.date }
                cachedSummary = nil
                return false
            }
            reloadWidget()
            return true
        }
        
        entries.remove(at: index)
        cachedSummary = nil
        reloadWidget()
        return true
    }

    /// Deletes the full log in one save operation.
    @discardableResult
    func deleteAll() -> Bool {
        guard !entries.isEmpty else { return true }
        let previousEntries = entries

        switch storageMode {
        case .swiftData(let context):
            do {
                let storedEntries = try context.fetch(FetchDescriptor<FuelEntrySD>())
                for storedEntry in storedEntries {
                    context.delete(storedEntry)
                }
                try context.save()
            } catch {
                context.rollback()
                lastError = .deleteFailed(reason: error.localizedDescription)
                return false
            }
        case .json:
            entries.removeAll()
            cachedSummary = nil
            guard persistIfJSON() else {
                entries = previousEntries
                cachedSummary = nil
                return false
            }
            reloadWidget()
            return true
        }

        entries.removeAll()
        cachedSummary = nil
        reloadWidget()
        return true
    }

    func summary() -> FuelSummary {
        if let cachedSummary {
            return cachedSummary
        }
        let completed = visibleEntries.filter { $0.distance != nil }
        let cycles = FuelCycleService.completedCycles(from: visibleEntries)
        let distance = completed.compactMap { $0.distance }.reduce(0, +)
        let cycleDistance = cycles.reduce(0) { $0 + $1.distance }
        let litersForEfficiency = cycles.reduce(0) { $0 + $1.liters }
        let costForEfficiency = cycles.reduce(0) { $0 + $1.cost }
        let totalLiters = visibleEntries.reduce(0) { $0 + $1.totalLiters }
        let totalCost = visibleEntries.reduce(0) { $0 + $1.totalCost }

        let lPer100 = cycleDistance > 0 ? (litersForEfficiency / cycleDistance) * 100 : nil
        let costPerKM = cycleDistance > 0 ? costForEfficiency / cycleDistance : nil

        let recent = Array(cycles.suffix(5))
        let recentLPer100 = recent.map(\.litersPer100KM).average()
        let recentCostPerKM = recent.map(\.costPerKM).average()

        let modes = Dictionary(grouping: cycles, by: { $0.driveMode })
            .mapValues { group -> DriveModeBreakdown in
                let modeDistance = group.reduce(0) { $0 + $1.distance }
                let modeLiters = group.reduce(0) { $0 + $1.liters }
                let modeCost = group.reduce(0) { $0 + $1.cost }

                let lPer100 = modeDistance > 0 ? (modeLiters / modeDistance) * 100 : nil
                let costPerKM = modeDistance > 0 ? modeCost / modeDistance : nil
                return DriveModeBreakdown(distance: modeDistance, lPer100KM: lPer100, costPerKM: costPerKM)
            }

        let result = FuelSummary(
            totalDistance: distance,
            totalLiters: totalLiters,
            totalCost: totalCost,
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
            guard FileManager.default.fileExists(atPath: url.path) else {
                return
            }
            do {
                let data = try Data(contentsOf: url)
                entries = try decoder.decode([FuelEntry].self, from: data)
                cachedSummary = nil
            } catch {
                lastError = .loadFailed(reason: error.localizedDescription)
            }

        case .swiftData(let context):
            let descriptor = FetchDescriptor<FuelEntrySD>(
                sortBy: [SortDescriptor(\.date)]
            )
            do {
                let sdEntries = try context.fetch(descriptor)
                entries = sdEntries.map { $0.toFuelEntry() }
                cachedSummary = nil
            } catch {
                lastError = .loadFailed(reason: error.localizedDescription)
            }
        }
    }
    
    /// Persists to disk only if using JSON storage
    @discardableResult
    private func persistIfJSON() -> Bool {
        guard case .json(let url, let encoder, _) = storageMode else { return true }
        do {
            let data = try encoder.encode(entries)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return true
        } catch {
            lastError = .saveFailed(reason: error.localizedDescription)
            return false
        }
    }

    private func reloadWidget() {
        let defaults = UserDefaults(suiteName: "group.com.oktan.data")
        if let last = entries.last {
            defaults?.set(last.date.timeIntervalSinceReferenceDate, forKey: "widget.lastDate")
            defaults?.set(last.totalCost, forKey: "widget.lastCost")
            let recentEfficiencies = FuelCycleService.completedCycles(from: entries).suffix(10).map(\.litersPer100KM)
            let average = recentEfficiencies.isEmpty
                ? nil
                : recentEfficiencies.reduce(0, +) / Double(recentEfficiencies.count)
            defaults?.set(average, forKey: "widget.efficiency")
            defaults?.set(entries.count, forKey: "widget.entryCount")
        } else {
            for key in ["widget.lastDate", "widget.lastCost", "widget.efficiency", "widget.entryCount"] {
                defaults?.removeObject(forKey: key)
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "QuickStatsWidget")
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
        let cyclesByEntryID = Dictionary(uniqueKeysWithValues: FuelCycleService.completedCycles(from: entries)
            .map { ($0.id, $0) })

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
            let cycle = cyclesByEntryID[entry.id]
            let lPer100 = cycle.map { String(format: "%.2f", $0.litersPer100KM) } ?? ""
            let costPerKM = cycle.map { String(format: "%.3f", $0.costPerKM) } ?? ""
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
