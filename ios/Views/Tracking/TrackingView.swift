import SwiftUI

struct TrackingView: View {
    @EnvironmentObject private var repository: FuelRepository
    @State private var isPresentingForm = false
    @State private var entryToEdit: FuelEntry?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Log each refuel with a few taps. We calculate distance, efficiency, and cost automatically.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

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
                    .accessibilityIdentifier("add-fillup-button")
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
        }
    }
}

private struct FuelEntryRow: View {
    let entry: FuelEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                    Text(entry.gasStation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.totalCost, format: .currency(code: AppConfiguration.currencyCode))
                    .font(.headline)
            }

            HStack {
                Label("\(entry.totalLiters, specifier: "%.1f") L", systemImage: "fuelpump.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let distance = entry.distance {
                    Spacer()
                    Label("\(distance, specifier: "%.0f") km", systemImage: "road.lanes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lPer100 = entry.litersPer100KM {
                    Spacer()
                    Label("\(lPer100, specifier: "%.1f") L/100 km", systemImage: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .confirmationDialog("Delete this fill-up?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

#Preview {
    TrackingView()
        .environmentObject(FuelRepository())
}
