import WidgetKit
import SwiftUI
import SwiftData

enum QuickStatsWidgetModule {
    fileprivate struct QuickStatsProvider: TimelineProvider {
        func placeholder(in context: Context) -> QuickStatsEntry {
            QuickStatsEntry(date: Date(), efficiency: "8.5 L/100km", lastFillup: "2 days ago", cost: "QAR 50.00", fillupCount: 8)
        }

        func getSnapshot(in context: Context, completion: @escaping (QuickStatsEntry) -> ()) {
            let entry = QuickStatsEntry(date: Date(), efficiency: "8.5 L/100km", lastFillup: "Today", cost: "QAR 50.00", fillupCount: 8)
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
            if let snapshot = fetchSnapshot() {
                return snapshot
            }
            do {
                // Data is shared with the app via the App Group container.
                let container = try DataContainer.create(inMemory: false)
                let context = ModelContext(container)

                // Only the most recent entries are needed; avoid fetching the full log.
                var descriptor = FetchDescriptor<FuelEntrySD>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                descriptor.fetchLimit = 10
                let entries = try context.fetch(descriptor)
                let sharedDefaults = UserDefaults(suiteName: "group.com.oktan.data")
                let efficiencyUnit = sharedDefaults?.string(forKey: "efficiencyUnit") ?? "L/100km"
                let currencyCode = sharedDefaults?.string(forKey: "currencyCode") ?? "QAR"

                if let last = entries.first {
                    // Try to get latest efficiency
                    var effDisplay = "—"
                    if let effValue = last.litersPer100KM, effValue > 0 {
                         effDisplay = formatEfficiency(effValue, unit: efficiencyUnit)
                    } else {
                        // Fallback: average over the recent entries
                        let validEntries = entries.compactMap { $0.litersPer100KM }
                        if !validEntries.isEmpty {
                            let sum = validEntries.reduce(0, +)
                            let avg = sum / Double(validEntries.count)
                            effDisplay = "Avg: \(formatEfficiency(avg, unit: efficiencyUnit))"
                        } else if entries.count == 1 {
                             effDisplay = "First Log"
                        }
                    }

                    let date = last.date.formatted(date: .abbreviated, time: .omitted)
                    let cost = last.totalCost.formatted(.currency(code: currencyCode))
                    return QuickStatsEntry(date: Date(), efficiency: effDisplay, lastFillup: date, cost: cost, fillupCount: entries.count)
                }
            } catch {
                print("Widget fetch error: \(error)")
            }
            return QuickStatsEntry(date: Date(), efficiency: "—", lastFillup: "No Data", cost: "—", fillupCount: 0)
        }

        private func fetchSnapshot() -> QuickStatsEntry? {
            guard let defaults = UserDefaults(suiteName: "group.com.oktan.data"),
                  defaults.object(forKey: "widget.lastDate") != nil else { return nil }
            let lastDate = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: "widget.lastDate"))
            let costValue = defaults.double(forKey: "widget.lastCost")
            let currencyCode = defaults.string(forKey: "currencyCode") ?? "QAR"
            let efficiencyUnit = defaults.string(forKey: "efficiencyUnit") ?? "L/100km"
            let efficiency = defaults.object(forKey: "widget.efficiency") == nil
                ? "—"
                : formatEfficiency(defaults.double(forKey: "widget.efficiency"), unit: efficiencyUnit)
            return QuickStatsEntry(
                date: Date(),
                efficiency: efficiency,
                lastFillup: lastDate.formatted(date: .abbreviated, time: .omitted),
                cost: costValue.formatted(.currency(code: currencyCode)),
                fillupCount: defaults.integer(forKey: "widget.entryCount")
            )
        }

        private func formatEfficiency(_ litersPer100KM: Double, unit: String) -> String {
            switch unit {
            case "km/L":
                return String(format: "%.1f km/L", 100 / litersPer100KM)
            case "MPG":
                return String(format: "%.1f MPG", 235.215 / litersPer100KM)
            default:
                return String(format: "%.1f L/100km", litersPer100KM)
            }
        }
    }

    fileprivate struct QuickStatsEntry: TimelineEntry {
        let date: Date
        let efficiency: String
        let lastFillup: String
        let cost: String
        let fillupCount: Int
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
            Group {
                if family == .systemMedium {
                    mediumContent
                } else {
                    smallContent
                }
            }
            .widgetURL(URL(string: "oktan://quick-log"))
            .containerBackground(for: .widget) {
                Color(uiColor: .systemBackground)
            }
        }

        private var smallContent: some View {
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
        }

        private var mediumContent: some View {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Oktan", systemImage: "fuelpump.fill")
                        .font(.headline)
                        .foregroundStyle(themeAccent)
                    Text(entry.efficiency)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                    Text("Recent efficiency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 12) {
                    stat(entry.lastFillup, label: "Last fill-up")
                    stat(entry.cost, label: "Cost")
                    stat("\(entry.fillupCount)", label: "Recent logs")
                }
            }
        }

        private func stat(_ value: String, label: String) -> some View {
            VStack(alignment: .trailing, spacing: 1) {
                Text(value).font(.caption.bold())
                Text(label).font(.caption2).foregroundStyle(.secondary)
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
