import SwiftUI

struct TrackingView: View {
    @EnvironmentObject private var repository: FuelRepository
    @Environment(AppSettings.self) private var settings
    @Environment(NotificationService.self) private var notificationService
    @State private var isPresentingForm = false
    @State private var entryToEdit: FuelEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.large) {
                    header
                    entriesSection
                }
                .padding(DesignSystem.Spacing.large)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DesignSystem.ColorPalette.background.ignoresSafeArea())
            .navigationTitle("Tracking")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isPresentingForm = true }) {
                        Label("Add Fill-up", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .tint(DesignSystem.ColorPalette.primaryBlue)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text("Log each refuel with a few taps. We calculate distance, efficiency, and cost automatically.")
                .font(.callout)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Recent fill-ups")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DesignSystem.ColorPalette.label)

            if repository.entries.isEmpty {
                emptyState
            } else {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    ForEach(repository.entries.sorted(by: { $0.date > $1.date })) { entry in
                        FuelEntryRow(
                            entry: entry,
                            settings: settings,
                            onEdit: { entryToEdit = entry },
                            onDelete: { repository.delete(entry) }
                        )
                    }
                }
                .accessibilityIdentifier(AccessibilityID.trackingEntryList)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "fuelpump")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            Text("No entries yet")
                .font(.headline)
            Text("Tap Add Fill-up to start tracking your fuel efficiency.")
                .font(.footnote)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Header: Date + Cost + Menu
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                        .foregroundStyle(DesignSystem.ColorPalette.label)
                    
                    Text(entry.gasStation)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(settings.formatCost(entry.totalCost))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignSystem.ColorPalette.label)
                    
                    Menu {
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
            }
            
            // Divider
            Divider()
                .overlay(DesignSystem.ColorPalette.glassTint)
            
            // Stats Grid
            HStack(spacing: 0) {
                // Liters
                statColumn(
                    title: "Fuel",
                    value: settings.formatVolume(entry.totalLiters),
                    icon: "fuelpump.fill",
                    color: DesignSystem.ColorPalette.primaryBlue
                )
                
                Spacer()
                
                // Distance (if available)
                if let distance = entry.distance {
                    statColumn(
                        title: "Distance",
                        value: settings.formatDistance(distance),
                        icon: "road.lanes",
                        color: DesignSystem.ColorPalette.deepPurple
                    )
                    Spacer()
                }
                
                // Efficiency (if available)
                if let lPer100 = entry.litersPer100KM {
                    statColumn(
                        title: "Efficiency",
                        value: settings.formatEfficiency(lPer100),
                        icon: "leaf.fill",
                        color: DesignSystem.ColorPalette.successGreen
                    )
                } else {
                    // Drive Mode fallback if no efficiency
                    statColumn(
                        title: "Mode",
                        value: entry.driveMode.rawValue,
                        icon: "steeringwheel",
                        color: driveModeColor
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .glassCard()
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
        case .eco: return DesignSystem.ColorPalette.successGreen
        case .normal: return DesignSystem.ColorPalette.primaryBlue
        case .sport: return DesignSystem.ColorPalette.warningOrange
        }
    }

    private func statColumn(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            }
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(DesignSystem.ColorPalette.label)
        }
        .frame(minWidth: 80, alignment: .leading)
    }
}

#Preview {
    TrackingView()
        .environmentObject(FuelRepository())
        .environment(AppSettings())
}
