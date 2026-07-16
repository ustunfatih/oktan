import Foundation

struct FuelEntry: Identifiable, Codable, Equatable {
    enum DriveMode: String, Codable, CaseIterable, Identifiable {
        case eco = "Eco"
        case normal = "Normal"
        case sport = "Sport"

        var id: String { rawValue }
    }

    let id: UUID
    var date: Date
    var odometerStart: Double?
    var odometerEnd: Double?
    var totalLiters: Double
    var pricePerLiter: Double
    var gasStation: String
    var driveMode: DriveMode
    var isFullRefill: Bool
    var notes: String?

    /// The car this fill-up belongs to. nil = recorded before multi-car
    /// support (treated as belonging to every car).
    var carId: UUID?

    init(
        id: UUID = UUID(),
        date: Date,
        odometerStart: Double?,
        odometerEnd: Double?,
        totalLiters: Double,
        pricePerLiter: Double,
        gasStation: String,
        driveMode: DriveMode,
        isFullRefill: Bool,
        notes: String? = nil,
        carId: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.odometerStart = odometerStart
        self.odometerEnd = odometerEnd
        self.totalLiters = totalLiters
        self.pricePerLiter = pricePerLiter
        self.gasStation = gasStation
        self.driveMode = driveMode
        self.isFullRefill = isFullRefill
        self.notes = notes
        self.carId = carId
    }
}

extension FuelEntry {
    var distance: Double? {
        guard let start = odometerStart, let end = odometerEnd, end > start else { return nil }
        return end - start
    }

    var totalCost: Double {
        totalLiters * pricePerLiter
    }

    var litersPer100KM: Double? {
        guard let distance, distance > 0 else { return nil }
        return (totalLiters / distance) * 100
    }

    var costPerKM: Double? {
        guard let distance, distance > 0 else { return nil }
        return totalCost / distance
    }

    func updatingOdometer(end: Double?) -> FuelEntry {
        var copy = self
        copy.odometerEnd = end
        return copy
    }
}
