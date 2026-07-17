import WidgetKit
import SwiftUI
import SwiftData

enum QuickStatsWidgetModule {
    fileprivate struct QuickStatsProvider: TimelineProvider {
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
                // Data is shared with the app via the App Group container.
                let container = try DataContainer.create(inMemory: false)
                let context = ModelContext(container)

                // Only the most recent entries are needed; avoid fetching the full log.
                var descriptor = FetchDescriptor<FuelEntrySD>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                descriptor.fetchLimit = 10
                let entries = try context.fetch(descriptor)

                if let last = entries.first {
                    // Try to get latest efficiency
                    var effDisplay = "—"
                    if let effValue = last.litersPer100KM, effValue > 0 {
                         effDisplay = String(format: "%.1f L/100km", effValue)
                    } else {
                        // Fallback: average over the recent entries
                        let validEntries = entries.compactMap { $0.litersPer100KM }
                        if !validEntries.isEmpty {
                            let sum = validEntries.reduce(0, +)
                            let avg = sum / Double(validEntries.count)
                            effDisplay = String(format: "Avg: %.1f", avg)
                        } else if entries.count == 1 {
                             effDisplay = "First Log"
                        }
                    }

                    let date = last.date.formatted(date: .abbreviated, time: .omitted)
                    let cost = String(format: "%.2f", last.totalCost)
                    return QuickStatsEntry(date: Date(), efficiency: effDisplay, lastFillup: date, cost: cost)
                }
            } catch {
                print("Widget fetch error: \(error)")
            }
            return QuickStatsEntry(date: Date(), efficiency: "—", lastFillup: "No Data", cost: "—")
        }
    }

    fileprivate struct QuickStatsEntry: TimelineEntry {
        let date: Date
        let efficiency: String
        let lastFillup: String
        let cost: String
    }

    fileprivate struct QuickStatsWidgetEntryView : View {
        var entry: QuickStatsProvider.Entry
        @Environment(\.widgetFamily) var family

        /// Accent from the app's selected theme, shared via the App Group
        private var themeAccent: Color {
            let themeId = UserDefaults(suiteName: "group.com.oktan.data")?.string(forKey: "themeId") ?? Theme.default.id
            return Theme.theme(id: themeId).accent
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "fuelpump.fill")
                        .foregroundStyle(themeAccent)
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
                Color(uiColor: .systemBackground)
            }
        }
    }

    struct OktanQuickStatsWidget: Widget {
        let kind: String = "QuickStatsWidget"

        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: QuickStatsWidgetModule.QuickStatsProvider()) { entry in
                QuickStatsWidgetModule.QuickStatsWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("Quick Stats")
            .description("View your latest fuel statistics at a glance.")
            .supportedFamilies([.systemSmall, .systemMedium])
        }
    }
}

@main
struct OktanWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickStatsWidgetModule.OktanQuickStatsWidget()
    }
}
