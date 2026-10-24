import Foundation

/// Produces completed efficiency cycles. Partial refills are accumulated until
/// the next full refill, so they never create misleading per-fill efficiency.
enum FuelCycleService {
    struct Cycle: Identifiable {
        let id: UUID
        let date: Date
        let distance: Double
        let liters: Double
        let cost: Double
        let driveMode: FuelEntry.DriveMode
        let station: String
        let entryCount: Int

        var litersPer100KM: Double { liters / distance * 100 }
        var costPerKM: Double { cost / distance }
    }

    static func completedCycles(from entries: [FuelEntry]) -> [Cycle] {
        var pending: [FuelEntry] = []
        var cycles: [Cycle] = []

        for entry in entries.sorted(by: { $0.date < $1.date }) {
            guard entry.distance != nil else { continue }
            pending.append(entry)

            guard entry.isFullRefill else { continue }
            let distance = pending.compactMap(\.distance).reduce(0, +)
            guard distance > 0 else {
                pending.removeAll(keepingCapacity: true)
                continue
            }

            cycles.append(Cycle(
                id: entry.id,
                date: entry.date,
                distance: distance,
                liters: pending.reduce(0) { $0 + $1.totalLiters },
                cost: pending.reduce(0) { $0 + $1.totalCost },
                driveMode: entry.driveMode,
                station: entry.gasStation,
                entryCount: pending.count
            ))
            pending.removeAll(keepingCapacity: true)
        }

        return cycles
    }
}
