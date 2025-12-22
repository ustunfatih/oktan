import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var repository: FuelRepository
    @Environment(AppSettings.self) private var settings
    
    // CarRepository: try environment first, fallback to creating new instance
    @Environment(CarRepository.self) private var envCarRepository: CarRepository?
    @Environment(CarRepositorySD.self) private var envCarRepositorySD: CarRepositorySD?
    @State private var localCarRepository: CarRepository?
    
    @State private var isPresentingForm = false
    @State private var isPresentingCarSelection = false
    @State private var refreshID = UUID()
    
    /// The active car repository (from environment or local)
    private var carRepository: CarRepositoryProtocol {
        if let sd = envCarRepositorySD {
            return sd
        }
        if let env = envCarRepository {
            return env
        }
        // Fallback: create local instance
        if localCarRepository == nil {
            localCarRepository = CarRepository()
        }
        return localCarRepository!
    }
    
    private var summary: FuelSummary {
        repository.summary()
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Car Section
                Section {
                    carSection
                        .id(refreshID)
                }
                .listRowBackground(Color.clear)
                
                // Hero Card Section
                Section {
                    heroCard
                }
                .listRowBackground(Color.clear)
                
                // Efficiency Section
                Section {
                    efficiencySection
                } header: {
                    Text("Efficiency")
                }
                
                // Recent Activity Section
                Section {
                    recentActivitySection
                } header: {
                    Text("Recent Activity")
                }
                
                // Quick Add Section
                Section {
                    quickAddButton
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Home")
            .sheet(isPresented: $isPresentingForm) {
                FuelEntryFormView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isPresentingCarSelection, onDismiss: {
                // Reload the local repository if we're using it
                if localCarRepository != nil {
                    localCarRepository = CarRepository()
                }
                refreshID = UUID()
            }) {
                CarSelectionView(carRepository: localCarRepository ?? CarRepository())
            }
        }
    }
    
    // MARK: - Car Section
    
    @ViewBuilder
    private var carSection: some View {
        if let car = carRepository.selectedCar {
            carDetailsView(car)
        } else {
            addCarButton
        }
    }
    
    private func carDetailsView(_ car: Car) -> some View {
        VStack(alignment: .leading) {
            // Car image
            if let imageData = car.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            // Car info
            Text("\(car.year) \(car.make)")
                .font(.headline)
            Text(car.model)
                .font(.title2.weight(.bold))

            // Tank capacity
            Text("Tank: \(settings.formatVolume(car.tankCapacity))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: { isPresentingCarSelection = true }) {
                Label("Change Car", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
            }
        }
        .padding() // No numeric value - Bible compliant
        .background(.ultraThinMaterial)
    }
    
    private var addCarButton: some View {
        Button(action: { isPresentingCarSelection = true }) {
            VStack {
                Image(systemName: "car.badge.gearshape")
                    .font(.largeTitle) // System font size - Bible compliant
                    .foregroundStyle(.tint)

                Text("Add Your Car")
                    .font(.headline)

                Text("Set up your car to track fuel efficiency")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding() // No numeric value - Bible compliant
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
        .accessibilityIdentifier("add-car-button")
    }
    
    // MARK: - Hero Card (Bible Compliant)
    // Removed: LinearGradient, RoundedRectangle, fixed font sizes, custom opacity

    private var heroCard: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Distance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(settings.formatDistance(summary.totalDistance))
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Total Spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(settings.formatCost(summary.totalCost))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Fill-ups")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(repository.entries.count)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(.tint.opacity(0.1)) // System tint with low opacity
        .background(.ultraThinMaterial)
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fuel summary")
        .accessibilityValue("Total distance \(settings.formatDistance(summary.totalDistance)), total spent \(settings.formatCost(summary.totalCost)), \(repository.entries.count) fill-ups")
        .accessibilityIdentifier(AccessibilityID.homeHeroCard)
    }
    
    // MARK: - Efficiency Section
    
    private var efficiencySection: some View {
        Group {
            // Average efficiency row
            HStack {
                Image(systemName: "gauge.with.needle")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text("Average")
                        .font(.headline)
                    Text("all time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(summary.averageLitersPer100KM.map { settings.formatEfficiency($0) } ?? "—")
                    .font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Average efficiency, all time")
            .accessibilityValue(summary.averageLitersPer100KM.map { settings.formatEfficiency($0) } ?? "Not available")
            
            // Recent efficiency row
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text("Recent")
                        .font(.headline)
                    Text("last 5 fill-ups")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(summary.recentAverageLitersPer100KM.map { settings.formatEfficiency($0) } ?? "—")
                    .font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Recent efficiency, last 5 fill-ups")
            .accessibilityValue(summary.recentAverageLitersPer100KM.map { settings.formatEfficiency($0) } ?? "Not available")
        }
    }
    
    // MARK: - Recent Activity Section
    
    @ViewBuilder
    private var recentActivitySection: some View {
        if repository.entries.isEmpty {
            ContentUnavailableView {
                Label("No Entries Yet", systemImage: "fuelpump")
            } description: {
                Text("Start tracking your fuel consumption")
            }
        } else {
            ForEach(repository.entries.sorted(by: { $0.date > $1.date }).prefix(3)) { entry in
                RecentEntryRow(entry: entry, settings: settings)
            }
        }
    }
    
    private var quickAddButton: some View {
        Button(action: { isPresentingForm = true }) {
            Label("Add Fill-up", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("home-add-fillup-button")
    }
}

// MARK: - Supporting Views

private struct RecentEntryRow: View {
    let entry: FuelEntry
    let settings: AppSettings
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                Text(entry.gasStation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(settings.formatCost(entry.totalCost))
                    .font(.headline)
                if let lPer100 = entry.litersPer100KM {
                    Text(settings.formatEfficiency(lPer100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fill-up on \(AccessibilityHelper.speakableDate(entry.date)) at \(entry.gasStation)")
        .accessibilityValue("\(settings.formatCost(entry.totalCost))" + (entry.litersPer100KM.map { ", efficiency \(settings.formatEfficiency($0))" } ?? ""))
        .accessibilityIdentifier(AccessibilityID.trackingEntryRow)
    }
}

#Preview {
    HomeView()
        .environmentObject(FuelRepository())
        .environment(AppSettings())
}
