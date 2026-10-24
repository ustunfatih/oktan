import Foundation
import OSLog
import SwiftData
import SwiftUI

/// Configures the SwiftData container for the app
/// Handles model registration, storage location, and iCloud sync preparation
enum DataContainer {
    private static let logger = Logger(subsystem: "com.oktan.app", category: "DataContainer")
    
    // MARK: - Schema
    
    /// All SwiftData models used in the app
    static let schema = Schema([
        FuelEntrySD.self,
        CarSD.self
    ])
    
    // MARK: - Configuration
    
    /// Default configuration for local storage (supporting App Groups)
    static var localConfiguration: ModelConfiguration {
        let appGroupID = "group.com.oktan.data"
        let url: URL
        
        // Safety check: Use App Group only if available and provisioned
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            url = groupURL.appendingPathComponent("Oktan.sqlite")
        } else {
            logger.warning("App Group container unavailable; using Application Support")
            url = URL.applicationSupportDirectory.appending(path: "Oktan.sqlite")
        }

        protectStoreDirectory(at: url.deletingLastPathComponent())

        // The app has no iCloud entitlement, so CloudKit is disabled explicitly
        // instead of letting .automatic fail and fall through at launch.
        return ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    }
    
    /// In-memory configuration for testing and previews
    static var inMemoryConfiguration: ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
    }
    
    // MARK: - Container Creation
    
    /// Creates the main model container for the app
    /// - Parameter inMemory: Whether to use in-memory storage (for testing/previews)
    /// - Returns: Configured ModelContainer
    static func create(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
        }
        
        do {
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            logger.error("Persistent store initialization failed; using default location: \(error.localizedDescription, privacy: .public)")

            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [fallbackConfig])
        }
    }

    private static func protectStoreDirectory(at url: URL) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        } catch {
            logger.error("Could not apply data protection: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Creates a container for SwiftUI previews with sample data
    @MainActor
    static func createPreviewContainer() throws -> ModelContainer {
        let container = try create(inMemory: true)
        let context = container.mainContext
        
        // Add sample fuel entries
        // Create a manual sample entry to avoid dependency on SeedData
        let sampleEntry = FuelEntrySD(
            date: Date(),
            odometerStart: 10000,
            odometerEnd: 10500,
            totalLiters: 45.0,
            pricePerLiter: 1.50,
            gasStation: "Shell",
            driveMode: .normal,
            isFullRefill: true
        )
        context.insert(sampleEntry)
        
        // Add sample car
        let sampleCar = CarSD(
            make: "Toyota",
            model: "Camry",
            year: 2024,
            tankCapacity: 60,
            isSelected: true
        )
        context.insert(sampleCar)
        
        try context.save()
        
        return container
    }
}

