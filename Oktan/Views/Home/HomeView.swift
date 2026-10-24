import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var repository: FuelRepository
    @Environment(AppSettings.self) private var settings
    @Environment(MilestoneService.self) private var milestoneService
    
    // CarRepository: try environment first, fallback to creating new instance
    @Environment(CarRepository.self) private var envCarRepository: CarRepository?
    @Environment(CarRepositorySD.self) private var envCarRepositorySD: CarRepositorySD?
    @State private var localCarRepository: CarRepository?
    
    @State private var isPresentingForm = false
    @State private var isPresentingCarSelection = false
    @State private var refreshID = UUID()
    @State private var animateHero = false
    @Namespace private var animation
    
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

    private var cycleEfficiencyByEntryID: [UUID: Double] {
        Dictionary(uniqueKeysWithValues: FuelCycleService.completedCycles(from: repository.visibleEntries)
            .map { ($0.id, $0.litersPer100KM) })
    }
    
    var body: some View {
        ListShell(title: "Home") {
            // Car Section
            Section {
                carSection
                    .id(refreshID)
            }
            .listRowBackground(Color.clear)
            
            // Milestones Section
            if !milestoneService.milestones.isEmpty {
                Section {
                    MilestoneRow(milestones: milestoneService.milestones)
                        .padding(.vertical, 8)
                } header: {
                    Text("Milestones")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            
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

            // Planning Section (prediction + budget)
            if nextFillupPrediction != nil || settings.monthlyBudget != nil || projectedMonthSpend != nil || serviceCheckpoint != nil {
                Section {
                    planningSection
                } header: {
                    Text("Planning")
                }
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
        .sheet(isPresented: $isPresentingForm) {
            FuelEntryFormView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isPresentingCarSelection) {
            if let sd = envCarRepositorySD {
                CarSelectionView(carRepository: envCarRepository ?? CarRepository())
                    .environment(sd)
            } else {
                CarSelectionView(carRepository: envCarRepository ?? localCarRepository ?? CarRepository())
            }
        }
        .onChange(of: repository.visibleEntries) { _, entries in
            milestoneService.checkMilestones(entries: entries, summary: summary)
        }
        .onAppear {
            milestoneService.checkMilestones(entries: repository.visibleEntries, summary: summary)
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
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("\(car.year.map { String($0) } ?? "") \(car.make)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    
                    Text(car.model)
                        .font(settings.currentTheme.displayFont(relativeTo: .title))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button(action: { isPresentingCarSelection = true }) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 20)
            
            HStack {
                VStack(alignment: .leading) {
                    Label(settings.formatVolume(car.tankCapacity), systemImage: "fuelpump.fill")
                        .font(.caption.bold())
                    Text("Tank Capacity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Show car image or placeholder
                if let imageData = car.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect)
                } else {
                    Image(systemName: "car.side.fill")
                        .font(.largeTitle)
                        .foregroundStyle(settings.accentColor.opacity(0.3))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect)
    }
    
    private var addCarButton: some View {
        Button(action: { isPresentingCarSelection = true }) {
            VStack {
                Image(systemName: "car.badge.gearshape")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)

                Text("Add Your Car")
                    .font(.headline)

                Text("Set up your car to track fuel efficiency")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
        .accessibilityIdentifier("add-car-button")
    }
    
    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Distance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(settings.formatDistance(summary.totalDistance))
                        .font(settings.currentTheme.displayFont(relativeTo: .largeTitle))
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
                    Text("\(repository.visibleEntries.count)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(settings.currentTheme.heroGradient)
        .background(.ultraThinMaterial)
        .clipShape(.rect)
        .offset(y: animateHero ? 0 : 20)
        .opacity(animateHero ? 1 : 0)
        .onAppear {
            withAnimation(.spring) {
                animateHero = true
            }
        }
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fuel summary")
        .accessibilityValue("Total distance \(settings.formatDistance(summary.totalDistance)), total spent \(settings.formatCost(summary.totalCost)), \(repository.visibleEntries.count) fill-ups")
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
    
    // MARK: - Planning Section

    private var nextFillupPrediction: ChartDataService.FillupPrediction? {
        ChartDataService.predictNextFillup(from: repository.visibleEntries)
    }

    /// Total spend for the current calendar month
    private var currentMonthSpend: Double {
        let calendar = Calendar.current
        return repository.visibleEntries
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.totalCost }
    }

    private var projectedMonthSpend: Double? {
        guard currentMonthSpend > 0 else { return nil }
        let calendar = Calendar.current
        let day = calendar.component(.day, from: Date())
        guard day >= 3,
              let days = calendar.range(of: .day, in: .month, for: Date())?.count else { return nil }
        return currentMonthSpend / Double(day) * Double(days)
    }

    private var serviceCheckpoint: (odometer: Double, remaining: Double)? {
        guard let latest = repository.visibleEntries.compactMap(\.odometerEnd).max() else { return nil }
        let checkpoint = (floor(latest / 10_000) + 1) * 10_000
        return (checkpoint, checkpoint - latest)
    }

    @ViewBuilder
    private var planningSection: some View {
        if let prediction = nextFillupPrediction {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text("Next fill-up")
                        .font(.headline)
                    Text("estimated from your history")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(prediction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.title3.weight(.semibold))
                    if let cost = prediction.estimatedCost {
                        Text("~\(settings.formatCost(cost))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(prediction.confidence.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Next fill-up estimated \(prediction.date.formatted(date: .long, time: .omitted))")
        }

        if let budget = settings.monthlyBudget, budget > 0 {
            VStack(alignment: .leading) {
                HStack {
                    Text("Monthly budget")
                        .font(.headline)
                    Spacer()
                    Text("\(settings.formatCost(currentMonthSpend)) of \(settings.formatCost(budget))")
                        .font(.caption)
                        .foregroundStyle(currentMonthSpend > budget ? .red : .secondary)
                }
                ProgressView(value: min(currentMonthSpend / budget, 1.0))
                    .tint(currentMonthSpend > budget ? .red : .green)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Monthly budget")
            .accessibilityValue("\(settings.formatCost(currentMonthSpend)) spent of \(settings.formatCost(budget))")
        }

        if let projectedMonthSpend {
            LabeledContent {
                Text("~\(settings.formatCost(projectedMonthSpend))")
                    .font(.headline)
            } label: {
                Label("Projected month-end spend", systemImage: "chart.line.uptrend.xyaxis")
            }
        }

        if let serviceCheckpoint {
            LabeledContent {
                Text(settings.formatDistance(serviceCheckpoint.remaining))
                    .font(.headline)
            } label: {
                Label("Next 10,000 km checkpoint", systemImage: "wrench.and.screwdriver")
            }
            .accessibilityValue("\(settings.formatDistance(serviceCheckpoint.remaining)) remaining until \(settings.formatDistance(serviceCheckpoint.odometer))")
        }
    }

    // MARK: - Recent Activity Section
    
    @ViewBuilder
    private var recentActivitySection: some View {
        if repository.visibleEntries.isEmpty {
            ContentUnavailableView {
                Label("No Entries Yet", systemImage: "fuelpump")
            } description: {
                Text("Start tracking your fuel consumption")
            }
        } else {
            ForEach(repository.visibleEntries.suffix(3).reversed()) { entry in
                RecentEntryRow(
                    entry: entry,
                    efficiency: cycleEfficiencyByEntryID[entry.id],
                    settings: settings
                )
            }
        }
    }
    
    private var quickAddButton: some View {
        Button(action: { 
            withAnimation(.spring()) {
                isPresentingForm = true 
            }
        }) {
            Label("Add Fill-up", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .matchedGeometryEffect(id: "addButton", in: animation)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("home-add-fillup-button")
    }
}

// MARK: - Supporting Views

private struct RecentEntryRow: View {
    let entry: FuelEntry
    let efficiency: Double?
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
                if let lPer100 = efficiency {
                    Text(settings.formatEfficiency(lPer100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fill-up on \(AccessibilityHelper.speakableDate(entry.date)) at \(entry.gasStation)")
        .accessibilityValue("\(settings.formatCost(entry.totalCost))" + (efficiency.map { ", efficiency \(settings.formatEfficiency($0))" } ?? ""))
        .accessibilityIdentifier(AccessibilityID.trackingEntryRow)
    }
}

#Preview {
    HomeView()
        .environmentObject(FuelRepository())
        .environment(AppSettings())
}
