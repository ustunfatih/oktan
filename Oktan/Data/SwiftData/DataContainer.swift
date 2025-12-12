import Foundation
import SwiftData
import SwiftUI

/// Configures the SwiftData container for the app
/// Handles model registration, storage location, and iCloud sync preparation
enum DataContainer {
    
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
            print("WARNING: App Group container unavailable. Fallback to local storage.")
            url = URL.applicationSupportDirectory.appending(path: "Oktan.sqlite")
        }

        // Use the appropriate initializer (schema, url)
        return ModelConfiguration(schema: schema, url: url)
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
            // Try enabling CloudKit (default behavior if entitlements exist)
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            print("CloudKit container failed to initialize: \(error). Falling back to local-only.")
            
            // Fallback: Disable CloudKit explicitly
            let localSchema = Schema([FuelEntrySD.self, CarSD.self])
            let fallbackConfig = ModelConfiguration(
                schema: localSchema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [fallbackConfig])
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


