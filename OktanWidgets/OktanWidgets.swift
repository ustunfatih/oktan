import WidgetKit
import SwiftUI
import SwiftData

struct QuickStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickStatsEntry {
        QuickStatsEntry(date: Date(), efficiency: "8.5 L/100km", lastFillup: "2 days ago", cost: "50.00")
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickStatsEntry) -> ()) {
        let entry = QuickStatsEntry(date: Date(), efficiency: "8.5 L/100km", lastFillup: "Today", cost: "50.00")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickStatsEntry>) -> ()) {
        let entry = fetchData()
        // Refresh every hour
        let nextUpdate = Date().addingTimeInterval(3600)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchData() -> QuickStatsEntry {
        do {
            // Attempt to create container. 
            // Note: For actual data sharing, App Groups must be configured.
            let container = try DataContainer.create(inMemory: false)
            // Create a background context
            let context = ModelContext(container)
            
            let descriptor = FetchDescriptor<FuelEntrySD>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let entries = try context.fetch(descriptor)
            
            if let last = entries.first {
                let effValue = last.litersPer100KM ?? 0
                let eff = effValue > 0 ? String(format: "%.1f L/100km", effValue) : "—"
                let date = last.date.formatted(date: .abbreviated, time: .omitted)
                let cost = String(format: "%.2f", last.totalCost)
                return QuickStatsEntry(date: Date(), efficiency: eff, lastFillup: date, cost: cost)
            }
        } catch {
            print("Widget fetch error: \(error)")
        }
        return QuickStatsEntry(date: Date(), efficiency: "—", lastFillup: "No Data", cost: "—")
    }
}

struct QuickStatsEntry: TimelineEntry {
    let date: Date
    let efficiency: String
    let lastFillup: String
    let cost: String
}

struct QuickStatsWidgetEntryView : View {
    var entry: QuickStatsProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "fuelpump.fill")
                    .foregroundStyle(.blue)
                Text("Oktan")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Spacer()
            
            VStack(alignment: .leading) {
                Text(entry.efficiency)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.8)
                Text("Efficiency")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.lastFillup)
                        .font(.caption)
                        .bold()
                    Text("Last")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(entry.cost)
                        .font(.caption)
                        .bold()
                    Text("Cost")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.white
        }
    }
}

struct QuickStatsWidget: Widget {
    let kind: String = "QuickStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStatsProvider()) { entry in
            QuickStatsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Stats")
        .description("View your latest fuel statistics at a glance.")
        .supportedFamilies([.systemSmall])
    }
}
