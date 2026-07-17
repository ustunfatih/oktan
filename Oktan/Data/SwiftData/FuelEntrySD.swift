import Foundation
import SwiftData

/// SwiftData model for fuel entries
/// This replaces the Codable struct-based FuelEntry for persistence
@Model
final class FuelEntrySD {
    
    // MARK: - Stored Properties
    
    /// Unique identifier matching the original FuelEntry.id
    @Attribute(.unique) var entryId: UUID
    
    /// Date of the fill-up
    var date: Date
    
    /// Odometer reading at the start of the trip (optional)
    var odometerStart: Double?
    
    /// Odometer reading at the end of the trip (optional)
    var odometerEnd: Double?
    
    /// Total liters of fuel purchased
    var totalLiters: Double
    
    /// Price per liter at time of purchase
    var pricePerLiter: Double
    
    /// Name of the gas station
    var gasStation: String
    
    /// Drive mode used (stored as raw string for SwiftData compatibility)
    var driveModeRaw: String
    
    /// Whether this was a full tank refill
    var isFullRefill: Bool
    
    /// Optional notes about the fill-up
    var notes: String?

    /// The car this fill-up belongs to (nil = legacy entry before multi-car support).
    /// Optional so SwiftData can migrate existing stores in place.
    var carId: UUID?

    /// Timestamp for sync conflict resolution
    var lastModified: Date
    
    // MARK: - Computed Properties
    
    /// Drive mode as typed enum
    var driveMode: FuelEntry.DriveMode {
        get { FuelEntry.DriveMode(rawValue: driveModeRaw) ?? .normal }
        set { driveModeRaw = newValue.rawValue }
    }
    
    /// Distance traveled (if both odometer values are present)
    var distance: Double? {
        guard let start = odometerStart, let end = odometerEnd, end > start else { return nil }
        return end - start
    }
    
    /// Total cost of the fill-up
    var totalCost: Double {
        totalLiters * pricePerLiter
    }
    
    /// Fuel efficiency in L/100km
    var litersPer100KM: Double? {
        guard let distance, distance > 0 else { return nil }
        return (totalLiters / distance) * 100
    }
    
    /// Cost per kilometer
    var costPerKM: Double? {
        guard let distance, distance > 0 else { return nil }
        return totalCost / distance
    }
    
    // MARK: - Initialization
    
    init(
        entryId: UUID = UUID(),
        date: Date,
        odometerStart: Double?,
        odometerEnd: Double?,
        totalLiters: Double,
        pricePerLiter: Double,
        gasStation: String,
        driveMode: FuelEntry.DriveMode,
        isFullRefill: Bool,
        notes: String? = nil,
        carId: UUID? = nil
    ) {
        self.entryId = entryId
        self.date = date
        self.odometerStart = odometerStart
        self.odometerEnd = odometerEnd
        self.totalLiters = totalLiters
        self.pricePerLiter = pricePerLiter
        self.gasStation = gasStation
        self.driveModeRaw = driveMode.rawValue
        self.isFullRefill = isFullRefill
        self.notes = notes
        self.carId = carId
        self.lastModified = Date()
    }
    
    // MARK: - Conversion Methods
    
    /// Creates a SwiftData entry from a legacy FuelEntry
    convenience init(from legacy: FuelEntry) {
        self.init(
            entryId: legacy.id,
            date: legacy.date,
            odometerStart: legacy.odometerStart,
            odometerEnd: legacy.odometerEnd,
            totalLiters: legacy.totalLiters,
            pricePerLiter: legacy.pricePerLiter,
            gasStation: legacy.gasStation,
            driveMode: legacy.driveMode,
            isFullRefill: legacy.isFullRefill,
            notes: legacy.notes,
            carId: legacy.carId
        )
    }
    
    /// Converts back to a FuelEntry struct (for compatibility with existing views)
    func toFuelEntry() -> FuelEntry {
        FuelEntry(
            id: entryId,
            date: date,
            odometerStart: odometerStart,
            odometerEnd: odometerEnd,
            totalLiters: totalLiters,
            pricePerLiter: pricePerLiter,
            gasStation: gasStation,
            driveMode: driveMode,
            isFullRefill: isFullRefill,
            notes: notes,
            carId: carId
        )
    }
    
    /// Updates all properties from a FuelEntry
    func update(from entry: FuelEntry) {
        self.date = entry.date
        self.odometerStart = entry.odometerStart
        self.odometerEnd = entry.odometerEnd
        self.totalLiters = entry.totalLiters
        self.pricePerLiter = entry.pricePerLiter
        self.gasStation = entry.gasStation
        self.driveModeRaw = entry.driveMode.rawValue
        self.isFullRefill = entry.isFullRefill
        self.notes = entry.notes
        self.carId = entry.carId
        self.lastModified = Date()
    }
}
