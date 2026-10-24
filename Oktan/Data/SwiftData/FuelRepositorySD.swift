import Foundation
import SwiftData
import Combine

/// SwiftData-based fuel repository
/// Replaces the JSON-based FuelRepository while maintaining API compatibility
@MainActor
@Observable
final class FuelRepositorySD {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    /// All fuel entries, sorted by date (oldest first)
    private(set) var entries: [FuelEntry] = []
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadEntries()
    }
    
    // MARK: - CRUD Operations
    
    /// Adds a new fuel entry
    @discardableResult
    func add(_ entry: FuelEntry) -> Bool {
        guard validate(entry) else { return false }
        
        let sdEntry = FuelEntrySD(from: entry)
        modelContext.insert(sdEntry)
        
        do {
            try modelContext.save()
            loadEntries()
            return true
        } catch {
            print("Failed to add entry: \(error)")
            return false
        }
    }
    
    /// Updates an existing fuel entry
    @discardableResult
    func update(_ entry: FuelEntry) -> Bool {
        guard validate(entry) else { return false }
        
        let descriptor = FetchDescriptor<FuelEntrySD>(
            predicate: #Predicate { $0.entryId == entry.id }
        )
        
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                existing.update(from: entry)
                try modelContext.save()
                loadEntries()
                return true
            }
        } catch {
            print("Failed to update entry: \(error)")
        }
        return false
    }
    
    /// Deletes a fuel entry
    @discardableResult
    func delete(_ entry: FuelEntry) -> Bool {
        let descriptor = FetchDescriptor<FuelEntrySD>(
            predicate: #Predicate { $0.entryId == entry.id }
        )
        
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                modelContext.delete(existing)
                try modelContext.save()
                loadEntries()
                return true
            }
        } catch {
            print("Failed to delete entry: \(error)")
        }
        return false
    }
    
    /// Loads entries from SwiftData
    func bootstrapIfNeeded() {
        loadEntries()
    }
    
    // MARK: - Summary
    
    func summary() -> FuelSummary {
        let completed = entries.filter { $0.distance != nil }
        
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
        
        return FuelSummary(
            totalDistance: distance,
            totalLiters: liters,
            totalCost: cost,
            averageLitersPer100KM: lPer100,
            averageCostPerKM: costPerKM,
            recentAverageLitersPer100KM: recentLPer100,
            recentAverageCostPerKM: recentCostPerKM,
            driveModeBreakdown: modes
        )
    }
    
    // MARK: - CSV Export
    
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
            let station = entry.gasStation.replacingOccurrences(of: ",", with: ";")
            let distance = entry.distance.map { String(format: "%.0f", $0) } ?? ""
            let lPer100 = entry.litersPer100KM.map { String(format: "%.2f", $0) } ?? ""
            let costPerKM = entry.costPerKM.map { String(format: "%.3f", $0) } ?? ""
            let notes = (entry.notes ?? "").replacingOccurrences(of: ",", with: ";")
            
            csv += "\(date),\(odometerStart),\(odometerEnd),\(liters),\(price),\(totalCost),\(fullRefill),\(driveMode),\(station),\(distance),\(lPer100),\(costPerKM),\(notes)\n"
        }
        
        return csv
    }
    
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
    
    // MARK: - Private Methods
    
    private func loadEntries() {
        let descriptor = FetchDescriptor<FuelEntrySD>(
            sortBy: [SortDescriptor(\.date)]
        )
        
        do {
            let sdEntries = try modelContext.fetch(descriptor)
            entries = sdEntries.map { $0.toFuelEntry() }
        } catch {
            print("Failed to load entries: \(error)")
            entries = []
        }
    }
    
    private func validate(_ entry: FuelEntry) -> Bool {
        guard entry.totalLiters > 0, entry.pricePerLiter > 0 else { return false }
        if let start = entry.odometerStart, let end = entry.odometerEnd, end < start { return false }
        return true
    }
}

// MARK: - Array Extension

private extension Array where Element == Double {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
