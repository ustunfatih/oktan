import Foundation

@MainActor
final class FuelRepository: ObservableObject {
    @Published private(set) var entries: [FuelEntry] = []
    private let storageURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(fileManager: FileManager = .default) {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        storageURL = directory.appendingPathComponent("fuel_entries.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func bootstrapIfNeeded() {
        if loadFromDisk() == false {
            entries = SeedData.entries
            persistToDisk()
        }
    }

    @discardableResult
    func add(_ entry: FuelEntry) -> Bool {
        guard validate(entry) else { return false }
        entries.append(entry)
        entries.sort { $0.date < $1.date }
        persistToDisk()
        return true
    }

    func update(_ entry: FuelEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }), validate(entry) else { return }
        entries[index] = entry
        entries.sort { $0.date < $1.date }
        persistToDisk()
    }

    func delete(_ entry: FuelEntry) {
        entries.removeAll { $0.id == entry.id }
        persistToDisk()
    }

    func summary() -> FuelSummary {
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

    private func validate(_ entry: FuelEntry) -> Bool {
        guard entry.totalLiters > 0, entry.pricePerLiter > 0 else { return false }
        if let start = entry.odometerStart, let end = entry.odometerEnd, end < start { return false }
        return true
    }

    @discardableResult
    private func loadFromDisk() -> Bool {
        guard let data = try? Data(contentsOf: storageURL) else { return false }
        guard let decoded = try? decoder.decode([FuelEntry].self, from: data) else { return false }
        entries = decoded
        return true
    }

    private func persistToDisk() {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
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
