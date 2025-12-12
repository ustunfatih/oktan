import Charts
import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var repository: FuelRepository
    @Environment(AppSettings.self) private var settings
    @Environment(PremiumManager.self) private var premiumManager
    @State private var showingExportSheet = false
    @State private var showingPaywall = false
    @State private var showingPDFAlert = false
    @State private var csvFileURL: URL?
    @State private var selectedTab: ReportTab = .overview
    
    enum ReportTab: String, CaseIterable {
        case overview = "Overview"
        case trends = "Trends"
        case patterns = "Patterns"
    }

    var body: some View {
        NavigationStack {
            let summary = repository.summary()
            
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Report Type", selection: $selectedTab) {
                    ForEach(ReportTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DesignSystem.Spacing.large)
                .padding(.top, DesignSystem.Spacing.medium)
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.large) {
                        switch selectedTab {
                        case .overview:
                            overviewContent(summary: summary)
                        case .trends:
                            trendsContent()
                        case .patterns:
                            patternsContent()
                        }
                    }
                    .padding(DesignSystem.Spacing.large)
                }
            }
            .background(DesignSystem.ColorPalette.background.ignoresSafeArea())
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: exportData) {
                            Label("Export to CSV", systemImage: "doc.text")
                        }
                        .disabled(repository.entries.isEmpty)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export options")
                    .accessibilityIdentifier(AccessibilityID.reportsExportButton)
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = csvFileURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("PDF Export", isPresented: $showingPDFAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("PDF export will be available in the next update. Please use CSV export for now.")
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
    
    // MARK: - Overview Tab
    
    @ViewBuilder
    private func overviewContent(summary: FuelSummary) -> some View {
        // Metrics Grid
        metricsGrid(summary: summary)
        
        // Month-over-Month Comparison
        PeriodComparisonCard(entries: repository.entries, settings: settings)
        
        // Insights
        InsightsCard(entries: repository.entries)
        
        // Export Section
        exportSection
    }
    
    // MARK: - Trends Tab
    
    @ViewBuilder
    private func trendsContent() -> some View {
        if premiumManager.isPremium {
            // Interactive Efficiency Chart
            EfficiencyTrendChart(entries: repository.entries, settings: settings)
            
            // Monthly Cost Chart
            MonthlyCostChart(entries: repository.entries, settings: settings)
            
            // Cost per km trend
            costPerKMChart
        } else {
            lockedState(message: "Unlock Trends to see detailed efficiency and cost analysis over time.")
        }
    }
    
    // MARK: - Patterns Tab
    
    @ViewBuilder
    private func patternsContent() -> some View {
        if premiumManager.isPremium {
            // Drive Mode Comparison
            DriveModeComparisonChart(entries: repository.entries, settings: settings)
            
            // Fill-up Frequency
            FillupFrequencyChart(entries: repository.entries)
            
            // Drive Mode Breakdown
            driveModeBreakdown(summary: repository.summary())
        } else {
            lockedState(message: "Unlock Patterns to discover your driving habits and optimal modes.")
        }
    }
    
    // MARK: - Metrics Grid
    
    private func metricsGrid(summary: FuelSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("At a Glance")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DesignSystem.ColorPalette.label)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.medium) {
                MetricCard(
                    title: "Total Distance",
                    value: settings.formatDistance(summary.totalDistance),
                    trend: "\(repository.entries.filter { $0.distance != nil }.count) tracked trips",
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    tint: DesignSystem.ColorPalette.primaryBlue
                )

                MetricCard(
                    title: "Total Fuel",
                    value: settings.formatVolume(summary.totalLiters),
                    trend: summary.averageLitersPer100KM.map { "Avg: \(settings.formatEfficiency($0))" },
                    icon: "drop.fill",
                    tint: DesignSystem.ColorPalette.deepPurple
                )

                MetricCard(
                    title: "Total Spent",
                    value: settings.formatCost(summary.totalCost),
                    trend: summary.averageCostPerKM.map { "Avg: \(settings.formatCostPerDistance($0))" },
                    icon: "creditcard.fill",
                    tint: DesignSystem.ColorPalette.successGreen
                )

                MetricCard(
                    title: "Recent Efficiency",
                    value: summary.recentAverageLitersPer100KM.map { settings.formatEfficiency($0) } ?? "N/A",
                    trend: summary.recentAverageCostPerKM.map { "Cost: \(settings.formatCostPerDistance($0))" },
                    icon: "waveform.path.ecg.rectangle",
                    tint: DesignSystem.ColorPalette.warningOrange
                )
            }
        }
    }
    
    // MARK: - Cost per KM Chart
    
    private var costPerKMChart: some View {
        let entries = repository.entries.filter { $0.costPerKM != nil }
        
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Cost per \(settings.distanceUnit.rawValue)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DesignSystem.ColorPalette.label)

            if entries.isEmpty {
                emptyChartState("Track odometer values to see cost trends")
            } else {
                Chart(entries) { entry in
                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Cost", settings.convertCostPerDistance(entry.costPerKM ?? 0))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignSystem.ColorPalette.successGreen.opacity(0.4),
                                DesignSystem.ColorPalette.successGreen.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Cost", settings.convertCostPerDistance(entry.costPerKM ?? 0))
                    )
                    .foregroundStyle(DesignSystem.ColorPalette.successGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("Cost per kilometer trend chart")
            }
        }
        .glassCard()
    }
    
    // MARK: - Drive Mode Breakdown
    
    private func driveModeBreakdown(summary: FuelSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Drive Mode Details")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DesignSystem.ColorPalette.label)

            if summary.driveModeBreakdown.isEmpty {
                emptyChartState("Log different drive modes to compare performance")
            } else {
                VStack(spacing: DesignSystem.Spacing.small) {
                    ForEach(FuelEntry.DriveMode.allCases) { mode in
                        if let breakdown = summary.driveModeBreakdown[mode] {
                            HStack {
                                Circle()
                                    .fill(colorForMode(mode))
                                    .frame(width: 10, height: 10)
                                
                                Text(mode.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(DesignSystem.ColorPalette.label)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let lPer100 = breakdown.lPer100KM {
                                        Text(settings.formatEfficiency(lPer100))
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(DesignSystem.ColorPalette.label)
                                    }
                                    if let cost = breakdown.costPerKM {
                                        Text(settings.formatCostPerDistance(cost))
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                                    }
                                }
                                
                                Text("\(settings.formatDistance(breakdown.distance))")
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.vertical, DesignSystem.Spacing.xsmall)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .glassCard()
    }
    
    private func colorForMode(_ mode: FuelEntry.DriveMode) -> Color {
        switch mode {
        case .eco: return DesignSystem.ColorPalette.successGreen
        case .normal: return DesignSystem.ColorPalette.primaryBlue
        case .sport: return DesignSystem.ColorPalette.errorRed
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Data Export")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DesignSystem.ColorPalette.label)
            
            HStack(spacing: DesignSystem.Spacing.medium) {
                Button(action: exportData) {
                    VStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                        Text("CSV")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.bordered)
                .tint(DesignSystem.ColorPalette.primaryBlue)
                .disabled(repository.entries.isEmpty)
                
                Button(action: { showingPDFAlert = true }) {
                    VStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: "doc.richtext")
                            .font(.title2)
                        Text("PDF")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.bordered)
                .tint(DesignSystem.ColorPalette.deepPurple)
            }
            
            if repository.entries.isEmpty {
                Text("Add some fill-ups to enable export")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            }
        }
        .glassCard()
    }
    
    // MARK: - Helpers
    
    private func emptyChartState(_ message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    private func lockedState(message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            
            Text(message)
                .font(.headline)
                .foregroundStyle(DesignSystem.ColorPalette.label)
                .multilineTextAlignment(.center)
            
            Button("Unlock Premium") {
                showingPaywall = true
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.ColorPalette.deepPurple)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard()
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func exportData() {
        csvFileURL = repository.createCSVFile()
        if csvFileURL != nil {
            showingExportSheet = true
        }
    }
}

// MARK: - Preview

#Preview {
    ReportsView()
        .environmentObject(FuelRepository())
        .environment(AppSettings())
}
