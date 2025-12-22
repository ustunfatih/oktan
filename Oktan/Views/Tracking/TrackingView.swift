import SwiftUI

struct TrackingView: View {
    @EnvironmentObject private var repository: FuelRepository
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationService.self) private var notificationService
    @State private var isPresentingForm = false
    @State private var entryToEdit: FuelEntry?

    var body: some View {
        NavigationStack {
            List {
                // Header Section
                Section {
                    Text("Log each refuel with a few taps. We calculate distance, efficiency, and cost automatically.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                
                // Entries Section
                Section {
                    if repository.entries.isEmpty {
                        ContentUnavailableView {
                            Label("No Entries Yet", systemImage: "fuelpump")
                        } description: {
                            Text("Tap Add Fill-up to start tracking your fuel efficiency.")
                        }
                    } else {
                        ForEach(repository.entries.sorted(by: { $0.date > $1.date })) { entry in
                            FuelEntryRow(
                                entry: entry,
                                settings: settings,
                                onEdit: { entryToEdit = entry },
                                onDelete: { repository.delete(entry) }
                            )
                        }
                    }
                } header: {
                    Text("Recent fill-ups")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tracking")
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
}

private struct FuelEntryRow: View {
    let entry: FuelEntry
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
        if let efficiency = entry.litersPer100KM {
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
                if let lPer100 = entry.litersPer100KM {
                    Label(settings.formatEfficiency(lPer100), systemImage: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label(entry.driveMode.rawValue, systemImage: "steeringwheel")
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
