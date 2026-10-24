import Foundation
import SwiftUI

struct Milestone: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    var dateAchieved: Date?
}

@Observable
final class MilestoneService {
    var milestones: [Milestone] = []
    
    func checkMilestones(entries: [FuelEntry], summary: FuelSummary) {
        var newMilestones: [Milestone] = []
        let cycles = FuelCycleService.completedCycles(from: entries)
        
        // 1. First Drop
        if let firstEntry = entries.sorted(by: { $0.date < $1.date }).first {
            newMilestones.append(Milestone(
                id: "first_drop",
                title: "First Drop",
                description: "Logged your first fill-up!",
                icon: "drop.fill",
                color: .blue,
                dateAchieved: firstEntry.date
            ))
        }
        
        // 2. Economy Master (Best efficiency)
        if let best = cycles.min(by: { $0.litersPer100KM < $1.litersPer100KM }) {
            newMilestones.append(Milestone(
                id: "economy_master",
                title: "Economy Master",
                description: "Achieved your best efficiency: \(String(format: "%.1f", best.litersPer100KM)) L/100km",
                icon: "leaf.fill",
                color: .green,
                dateAchieved: best.date
            ))
        }
        
        // 3. Long Haul (Longest distance)
        if let longest = cycles.max(by: { $0.distance < $1.distance }) {
            newMilestones.append(Milestone(
                id: "long_haul",
                title: "Long Haul",
                description: "Longest trip on a single tank: \(Int(longest.distance)) km",
                icon: "road.lanes",
                color: .orange,
                dateAchieved: longest.date
            ))
        }
        
        // 4. Road Warrior (Total Distance) - highest tier reached
        let totalDist = summary.totalDistance
        let distanceTiers: [(threshold: Double, tier: String)] = [
            (25_000, "IV"), (10_000, "III"), (5_000, "II"), (1_000, "I")
        ]
        if let tier = distanceTiers.first(where: { totalDist >= $0.threshold }) {
            newMilestones.append(Milestone(
                id: "road_warrior_\(Int(tier.threshold))",
                title: "Road Warrior \(tier.tier)",
                description: "Reached \(Int(tier.threshold).formatted()) km total distance!",
                icon: "crown.fill",
                color: .purple,
                dateAchieved: Date() // Simplified for now
            ))
        }

        // 5. Bargain Hunter (cheapest full fill)
        let fullFills = entries.filter { $0.isFullRefill }
        if let cheapest = fullFills.min(by: { $0.pricePerLiter < $1.pricePerLiter }),
           fullFills.count >= 3 {
            newMilestones.append(Milestone(
                id: "bargain_hunter",
                title: "Bargain Hunter",
                description: "Cheapest fill: \(String(format: "%.2f", cheapest.pricePerLiter))/L at \(cheapest.gasStation)",
                icon: "tag.fill",
                color: .teal,
                dateAchieved: cheapest.date
            ))
        }

        // 6. Best Month (lowest average efficiency in a calendar month)
        let calendar = Calendar.current
        let byMonth = Dictionary(grouping: cycles) {
            calendar.dateComponents([.year, .month], from: $0.date)
        }
        let monthAverages = byMonth.compactMapValues { group -> Double? in
            let values = group.map { $0.litersPer100KM }
            guard values.count >= 2 else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }
        if let best = monthAverages.min(by: { $0.value < $1.value }),
           let monthDate = calendar.date(from: best.key) {
            newMilestones.append(Milestone(
                id: "best_month",
                title: "Peak Performance",
                description: "Best month: \(monthDate.formatted(.dateTime.month(.wide).year())) at \(String(format: "%.1f", best.value)) L/100km",
                icon: "trophy.fill",
                color: .yellow,
                dateAchieved: monthDate
            ))
        }

        // 7. Dedicated Logger (fill-up count) - highest tier reached
        let countTiers = [100, 50, 25, 10]
        if let tier = countTiers.first(where: { entries.count >= $0 }) {
            newMilestones.append(Milestone(
                id: "dedicated_logger_\(tier)",
                title: "Dedicated Logger",
                description: "Logged \(tier)+ fill-ups!",
                icon: "checklist.checked",
                color: .indigo,
                dateAchieved: Date()
            ))
        }

        self.milestones = newMilestones
    }
}
