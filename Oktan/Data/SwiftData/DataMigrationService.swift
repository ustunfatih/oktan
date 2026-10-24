import Foundation
import SwiftData

/// Handles migration from JSON-based storage to SwiftData
/// This service ensures existing user data is preserved during the transition
enum DataMigrationService {
    
    // MARK: - Migration Status
    
    private static let migrationCompletedKey = "swiftDataMigrationCompleted"
    private static let migrationVersionKey = "swiftDataMigrationVersion"
    private static let currentMigrationVersion = 1
    
    /// Whether migration has already been completed
    static var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: migrationCompletedKey) &&
        UserDefaults.standard.integer(forKey: migrationVersionKey) >= currentMigrationVersion
    }
    
    /// Marks migration as completed
    private static func markMigrationCompleted() {
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)
    }
    
    // MARK: - JSON File Paths
    
    private static var fuelEntriesURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return directory.appendingPathComponent("fuel_entries.json")
    }
    
    private static var selectedCarURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return directory.appendingPathComponent("selected_car.json")
    }
    
    // MARK: - Migration
    
    /// Migrates existing JSON data to SwiftData
    /// - Parameter context: The SwiftData model context to insert data into
    /// - Returns: Number of entries migrated
    @MainActor
    static func migrateIfNeeded(context: ModelContext) async -> MigrationResult {
        guard !isMigrationCompleted else {
            return MigrationResult(fuelEntriesMigrated: 0, carMigrated: false, alreadyCompleted: true)
        }
        
        var result = MigrationResult(fuelEntriesMigrated: 0, carMigrated: false, alreadyCompleted: false)
        
        // Migrate fuel entries
        result.fuelEntriesMigrated = await migrateFuelEntries(context: context)
        
        // Migrate car
        result.carMigrated = await migrateCar(context: context)
        
        // Save changes
        do {
            try context.save()
            markMigrationCompleted()
            
            // Optionally backup and remove old JSON files
            backupAndCleanupOldFiles()
            
        } catch {
            print("Migration save failed: \(error)")
        }
        
        return result
    }
    
    // MARK: - Fuel Entries Migration
    
    @MainActor
    private static func migrateFuelEntries(context: ModelContext) async -> Int {
        guard FileManager.default.fileExists(atPath: fuelEntriesURL.path) else {
            return 0
        }
        
        do {
            guard let data = await readData(from: fuelEntriesURL) else { return 0 }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacyEntries = try decoder.decode([FuelEntry].self, from: data)
            
            for entry in legacyEntries {
                let sdEntry = FuelEntrySD(from: entry)
                context.insert(sdEntry)
            }
            
            return legacyEntries.count
        } catch {
            print("Failed to migrate fuel entries: \(error)")
            return 0
        }
    }
    
    // MARK: - Car Migration
    
    @MainActor
    private static func migrateCar(context: ModelContext) async -> Bool {
        guard FileManager.default.fileExists(atPath: selectedCarURL.path) else {
            return false
        }
        
        do {
            guard let data = await readData(from: selectedCarURL) else { return false }
            let decoder = JSONDecoder()
            let legacyCar = try decoder.decode(Car.self, from: data)
            
            let sdCar = CarSD(from: legacyCar, isSelected: true)
            context.insert(sdCar)
            
            return true
        } catch {
            print("Failed to migrate car: \(error)")
            return false
        }
    }

    private nonisolated static func readData(from url: URL) async -> Data? {
        await Task.detached(priority: .utility) {
            try? Data(contentsOf: url, options: [.mappedIfSafe])
        }.value
    }
    
    // MARK: - Cleanup
    
    private static func backupAndCleanupOldFiles() {
        let backupDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("legacy_backup")
        
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        
        // Backup fuel entries
        if FileManager.default.fileExists(atPath: fuelEntriesURL.path) {
            let backupURL = backupDirectory.appendingPathComponent("fuel_entries.json")
            try? FileManager.default.copyItem(at: fuelEntriesURL, to: backupURL)
            // Don't delete original yet - keep for safety
        }
        
        // Backup car
        if FileManager.default.fileExists(atPath: selectedCarURL.path) {
            let backupURL = backupDirectory.appendingPathComponent("selected_car.json")
            try? FileManager.default.copyItem(at: selectedCarURL, to: backupURL)
            // Don't delete original yet - keep for safety
        }
    }
    
    // MARK: - Reset (for testing)
    
    /// Resets migration status (useful for testing)
    static func resetMigrationStatus() {
        UserDefaults.standard.removeObject(forKey: migrationCompletedKey)
        UserDefaults.standard.removeObject(forKey: migrationVersionKey)
    }
}

// MARK: - Migration Result

struct MigrationResult {
    var fuelEntriesMigrated: Int
    var carMigrated: Bool
    let alreadyCompleted: Bool
    
    var description: String {
        if alreadyCompleted {
            return "Migration already completed"
        }
        return "Migrated \(fuelEntriesMigrated) fuel entries, car: \(carMigrated ? "yes" : "no")"
    }
}
