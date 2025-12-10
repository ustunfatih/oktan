import SwiftUI

struct TrackingView: View {
    @EnvironmentObject private var repository: FuelRepository
    @State private var isPresentingForm = false

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
                    .accessibilityIdentifier("add-fillup-button")
                }
            }
            .sheet(isPresented: $isPresentingForm) {
                FuelEntryFormView()
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text("Log each refuel with a few taps. We calculate distance, L/100km, and cost automatically.")
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
                        FuelEntryRow(entry: entry)
                    }
                }
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

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                    Text(entry.gasStation)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                }
                Spacer()
                Text(entry.driveMode.rawValue)
                    .font(.caption)
                    .padding(.horizontal, DesignSystem.Spacing.small)
                    .padding(.vertical, 6)
                    .background(DesignSystem.ColorPalette.glassTint)
                    .clipShape(Capsule())
            }

            HStack(spacing: DesignSystem.Spacing.medium) {
                if let distance = entry.distance {
                    valueChip(title: "Distance", value: distance, suffix: "km")
                }
                valueChip(title: "Fuel", value: entry.totalLiters, suffix: "L")
                Text(entry.totalCost, format: .currency(code: "QAR"))
                    .font(.headline)
                    .foregroundStyle(DesignSystem.ColorPalette.label)
            }

            if let lPer100 = entry.litersPer100KM {
                Text("\(lPer100, specifier: "%.2f") L / 100 km")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            }
        }
        .glassCard()
    }

    private func valueChip(title: String, value: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            Text("\(value, specifier: "%.0f") \(suffix)")
                .font(.headline)
        }
    }
}
