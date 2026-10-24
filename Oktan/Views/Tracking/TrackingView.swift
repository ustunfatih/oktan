import SwiftUI

struct TrackingView: View {
    @EnvironmentObject private var repository: FuelRepository
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationService.self) private var notificationService
    @State private var isPresentingForm = false
    @State private var entryToEdit: FuelEntry?

    private struct MonthSection {
        let title: String
        let entries: [FuelEntry]
    }

    /// Entries grouped by month, newest first. Repository entries are kept
    /// sorted ascending, so a single reverse pass avoids re-sorting per render.
    private var monthlySections: [MonthSection] {
        var sections: [MonthSection] = []
        var currentTitle = ""
        var currentEntries: [FuelEntry] = []

        for entry in repository.visibleEntries.reversed() {
            let title = entry.date.formatted(.dateTime.month(.wide).year())
            if title != currentTitle {
                if !currentEntries.isEmpty {
                    sections.append(MonthSection(title: currentTitle, entries: currentEntries))
                }
                currentTitle = title
                currentEntries = []
            }
            currentEntries.append(entry)
        }
        if !currentEntries.isEmpty {
            sections.append(MonthSection(title: currentTitle, entries: currentEntries))
        }
        return sections
    }

    private var cycleEfficiencyByEntryID: [UUID: Double] {
        Dictionary(uniqueKeysWithValues: FuelCycleService.completedCycles(from: repository.visibleEntries)
            .map { ($0.id, $0.litersPer100KM) })
    }

    var body: some View {
        ListShell(title: "Tracking") {
            // Header Section
            Section {
                Text("Log each refuel with a few taps. We calculate distance, efficiency, and cost automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            
            // Entries, newest first, grouped by month
            if repository.visibleEntries.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Entries Yet", systemImage: "fuelpump")
                    } description: {
                        Text("Tap Add Fill-up to start tracking your fuel efficiency.")
                    }
                } header: {
                    Text("Recent fill-ups")
                }
            } else {
                ForEach(monthlySections, id: \.title) { section in
                    Section {
                        ForEach(section.entries) { entry in
                            FuelEntryRow(
                                entry: entry,
                                cycleEfficiency: cycleEfficiencyByEntryID[entry.id],
                                settings: settings,
                                onEdit: { entryToEdit = entry },
                                onDelete: { repository.delete(entry) }
                            )
                        }
                    } header: {
                        Text(section.title)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isPresentingForm = true }) {
                    Label("Add Fill-up", systemImage: "plus.circle.fill")
                }
                .accessibilityLabel("Add new fill-up")
                .accessibilityHint("Opens a form to log a new refuel")
                .accessibilityIdentifier(AccessibilityID.trackingAddButton)
            }
        }
        .sheet(isPresented: $isPresentingForm) {
            FuelEntryFormView()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $entryToEdit) { entry in
            FuelEntryFormView(existingEntry: entry)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: notificationService.shouldShowAddFuel) { _, shouldShow in
            if shouldShow {
                isPresentingForm = true
                notificationService.shouldShowAddFuel = false
            }
        }
    }
}

private struct FuelEntryRow: View {
    let entry: FuelEntry
    let cycleEfficiency: Double?
    let settings: AppSettings
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false
    
    /// Accessibility summary for VoiceOver
    private var accessibilitySummary: String {
        var parts: [String] = []
        parts.append("\(AccessibilityHelper.speakableDate(entry.date)) at \(entry.gasStation)")
        parts.append("\(settings.formatVolume(entry.totalLiters)) of fuel")
        parts.append("cost \(settings.formatCost(entry.totalCost))")
        if let distance = entry.distance {
            parts.append("distance \(settings.formatDistance(distance))")
        }
        if let efficiency = cycleEfficiency {
            parts.append("efficiency \(settings.formatEfficiency(efficiency))")
        }
        parts.append("\(entry.driveMode.rawValue) mode")
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading) {
            // Header: Date + Station + Cost
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                    Text(entry.gasStation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(settings.formatCost(entry.totalCost))
                    .font(.title3.weight(.bold))
            }
            
            // Stats Row
            HStack {
                // Fuel
                Label(settings.formatVolume(entry.totalLiters), systemImage: "fuelpump.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Spacer()
                
                // Distance
                if let distance = entry.distance {
                    Label(settings.formatDistance(distance), systemImage: "road.lanes")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    Spacer()
                }
                
                // Efficiency or Mode
                if let lPer100 = cycleEfficiency {
                    Label(settings.formatEfficiency(lPer100), systemImage: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label(entry.isFullRefill ? entry.driveMode.rawValue : String(localized: "Partial fill"), systemImage: entry.isFullRefill ? "steeringwheel" : "circle.lefthalf.filled")
                        .font(.caption)
                        .foregroundStyle(driveModeColor)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
        }
        // Accessibility
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Fill-up entry")
        .accessibilityValue(accessibilitySummary)
        .confirmationDialog("Delete this fill-up?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private var driveModeColor: Color {
        switch entry.driveMode {
        case .eco: return .green
        case .normal: return .blue
        case .sport: return .orange
        }
    }
}

#Preview {
    TrackingView()
        .environmentObject(FuelRepository())
        .environment(AppSettings())
}
