import Charts
import SwiftUI

// MARK: - iOS 26 Design Bible Compliant ReportsView
// Removed: ScrollView + VStack, DesignSystem.Spacing.*, DesignSystem.ColorPalette.*,
//          .frame(height: N), .tint(), .glassCard(), LinearGradient

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

            List {
                // Tab Picker Section
                Section {
                    Picker("Report Type", selection: $selectedTab) {
                        ForEach(ReportTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                // Content based on selected tab
                switch selectedTab {
                case .overview:
                    overviewContent(summary: summary)
                case .trends:
                    trendsContent()
                case .patterns:
                    patternsContent()
                }
            }
            .listStyle(.insetGrouped)
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
        // Metrics Section
        Section {
            metricsContent(summary: summary)
        } header: {
            Text("At a Glance")
        }

        // Period Comparison Section
        Section {
            periodComparisonContent()
        } header: {
            Text("Month-over-Month")
        }

        // Insights Section
        Section {
            insightsContent()
        } header: {
            Label("Insights", systemImage: "lightbulb.fill")
        }

        // Export Section
        Section {
            exportContent()
        } header: {
            Text("Data Export")
        }
    }

    // MARK: - Trends Tab

    @ViewBuilder
    private func trendsContent() -> some View {
        if premiumManager.isPremium {
            // Efficiency Chart Section
            Section {
                efficiencyChartContent()
            } header: {
                Text("Efficiency Trend")
            }

            // Monthly Cost Section
            Section {
                monthlyCostChartContent()
            } header: {
                Text("Monthly Spending")
            }

            // Cost per KM Section
            Section {
                costPerKMChartContent()
            } header: {
                Text("Cost per \(settings.distanceUnit.rawValue)")
            }
        } else {
            Section {
                lockedContent(message: "Unlock Trends to see detailed efficiency and cost analysis over time.")
            }
        }
    }

    // MARK: - Patterns Tab

    @ViewBuilder
    private func patternsContent() -> some View {
        if premiumManager.isPremium {
            // Drive Mode Comparison Section
            Section {
                driveModeChartContent()
            } header: {
                Text("Efficiency by Drive Mode")
            }

            // Fill-up Frequency Section
            Section {
                fillupFrequencyContent()
            } header: {
                Text("Fill-up Patterns")
            }

            // Drive Mode Details Section
            Section {
                driveModeDetailsContent(summary: repository.summary())
            } header: {
                Text("Drive Mode Details")
            }
        } else {
            Section {
                lockedContent(message: "Unlock Patterns to discover your driving habits and optimal modes.")
            }
        }
    }

    // MARK: - Metrics Content

    private func metricsContent(summary: FuelSummary) -> some View {
        Group {
            // Total Distance
            LabeledContent {
                VStack(alignment: .trailing) {
                    Text(settings.formatDistance(summary.totalDistance))
                        .font(.headline)
                    Text("\(repository.entries.filter { $0.distance != nil }.count) tracked trips")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Label("Total Distance", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }

            // Total Fuel
            LabeledContent {
                VStack(alignment: .trailing) {
                    Text(settings.formatVolume(summary.totalLiters))
                        .font(.headline)
                    if let avg = summary.averageLitersPer100KM {
                        Text("Avg: \(settings.formatEfficiency(avg))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label("Total Fuel", systemImage: "drop.fill")
            }

            // Total Spent
            LabeledContent {
                VStack(alignment: .trailing) {
                    Text(settings.formatCost(summary.totalCost))
                        .font(.headline)
                    if let avg = summary.averageCostPerKM {
                        Text("Avg: \(settings.formatCostPerDistance(avg))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label("Total Spent", systemImage: "creditcard.fill")
            }

            // Recent Efficiency
            LabeledContent {
                VStack(alignment: .trailing) {
                    Text(summary.recentAverageLitersPer100KM.map { settings.formatEfficiency($0) } ?? "N/A")
                        .font(.headline)
                    if let cost = summary.recentAverageCostPerKM {
                        Text("Cost: \(settings.formatCostPerDistance(cost))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label("Recent Efficiency", systemImage: "waveform.path.ecg.rectangle")
            }
        }
    }

    // MARK: - Period Comparison Content

    private func periodComparisonContent() -> some View {
        let comparison = ChartDataService.monthOverMonthComparison(from: repository.entries)

        return Group {
            if let current = comparison.currentPeriod,
               (current.averageEfficiency != nil || current.averageCostPerKM != nil) {
                // Efficiency
                if let efficiency = current.averageEfficiency {
                    LabeledContent {
                        HStack {
                            Text(settings.formatEfficiency(efficiency))
                                .font(.headline)
                            if let change = comparison.efficiencyChange {
                                trendIndicator(change: change, isLowerBetter: true)
                            }
                        }
                    } label: {
                        Text("Efficiency")
                    }
                }

                // Cost per km
                if let costPerKM = current.averageCostPerKM {
                    LabeledContent {
                        HStack {
                            Text(settings.formatCostPerDistance(costPerKM))
                                .font(.headline)
                            if let change = comparison.costChange {
                                trendIndicator(change: change, isLowerBetter: true)
                            }
                        }
                    } label: {
                        Text("Cost/km")
                    }
                }
            } else {
                Label("Add odometer readings to see efficiency trends", systemImage: "gauge.badge.plus")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func trendIndicator(change: Double, isLowerBetter: Bool) -> some View {
        let isGood = isLowerBetter ? change < 0 : change > 0
        return HStack {
            Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
            Text("\(String(format: "%.0f", abs(change)))%")
        }
        .font(.caption)
        .foregroundStyle(isGood ? .green : .red)
    }

    // MARK: - Insights Content

    private func insightsContent() -> some View {
        let insights = ChartDataService.generateInsights(from: repository.entries)

        return Group {
            if insights.isEmpty {
                Text("Keep logging fill-ups to unlock insights about your driving patterns.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(insights.prefix(4).enumerated()), id: \.offset) { _, insight in
                    Label(insight, systemImage: "arrow.right.circle.fill")
                }
            }
        }
    }

    // MARK: - Export Content

    private func exportContent() -> some View {
        Group {
            Button(action: exportData) {
                Label("Export to CSV", systemImage: "doc.text")
            }
            .disabled(repository.entries.isEmpty)

            Button(action: { showingPDFAlert = true }) {
                Label("Export to PDF", systemImage: "doc.richtext")
            }

            if repository.entries.isEmpty {
                Text("Add some fill-ups to enable export")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Efficiency Chart Content

    private func efficiencyChartContent() -> some View {
        let trendData = ChartDataService.efficiencyTrend(from: repository.entries)
        let rollingAverage = ChartDataService.rollingAverageEfficiency(from: repository.entries)

        return Group {
            if trendData.isEmpty {
                emptyChartLabel("Add odometer readings to see efficiency trends")
            } else {
                Chart {
                    ForEach(trendData) { point in
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Efficiency", settings.convertEfficiency(point.value))
                        )
                        .foregroundStyle(.blue.opacity(0.6))
                    }

                    ForEach(rollingAverage) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Average", settings.convertEfficiency(point.value))
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .aspectRatio(1.5, contentMode: .fit) // Use aspect ratio instead of fixed height
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Efficiency trend chart showing \(trendData.count) data points")
                .accessibilityIdentifier(AccessibilityID.reportsChart)
            }
        }
    }

    // MARK: - Monthly Cost Chart Content

    private func monthlyCostChartContent() -> some View {
        let monthlyData = ChartDataService.aggregateMonthly(from: repository.entries)

        return Group {
            if monthlyData.isEmpty {
                emptyChartLabel("Track fill-ups to see monthly spending")
            } else {
                Chart(monthlyData) { month in
                    BarMark(
                        x: .value("Month", month.monthLabel),
                        y: .value("Cost", month.totalCost)
                    )
                    .foregroundStyle(.purple)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(orientation: .verticalReversed)
                    }
                }
                .aspectRatio(1.5, contentMode: .fit)
            }
        }
    }

    // MARK: - Cost per KM Chart Content

    private func costPerKMChartContent() -> some View {
        let entries = repository.entries.filter { $0.costPerKM != nil }

        return Group {
            if entries.isEmpty {
                emptyChartLabel("Track odometer values to see cost trends")
            } else {
                Chart(entries) { entry in
                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Cost", settings.convertCostPerDistance(entry.costPerKM ?? 0))
                    )
                    .foregroundStyle(.green.opacity(0.3)) // System color with opacity
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Cost", settings.convertCostPerDistance(entry.costPerKM ?? 0))
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .aspectRatio(1.5, contentMode: .fit)
                .accessibilityLabel("Cost per kilometer trend chart")
            }
        }
    }

    // MARK: - Drive Mode Chart Content

    private func driveModeChartContent() -> some View {
        let comparisonData = ChartDataService.driveModeComparison(from: repository.entries)

        return Group {
            if comparisonData.isEmpty {
                emptyChartLabel("Log different drive modes to compare efficiency")
            } else {
                Chart(comparisonData) { point in
                    BarMark(
                        x: .value("Mode", point.category),
                        y: .value("Efficiency", settings.convertEfficiency(point.value))
                    )
                    .foregroundStyle(colorForModeCategory(point.category))
                    .annotation(position: .top) {
                        Text(settings.formatEfficiency(settings.convertEfficiency(point.value)))
                            .font(.caption.weight(.medium))
                    }
                }
                .aspectRatio(1.5, contentMode: .fit)
            }
        }
    }

    private func colorForModeCategory(_ category: String) -> Color {
        switch category {
        case "Eco": return .green
        case "Sport": return .red
        default: return .blue
        }
    }

    // MARK: - Fill-up Frequency Content

    private func fillupFrequencyContent() -> some View {
        let dayOfWeekData = ChartDataService.fillupsByDayOfWeek(from: repository.entries)
        let averageDays = ChartDataService.averageDaysBetweenFillups(from: repository.entries)

        return Group {
            if let avg = averageDays {
                LabeledContent("Average Interval", value: "Every \(Int(avg)) days")
            }

            if dayOfWeekData.isEmpty || repository.entries.count < 3 {
                emptyChartLabel("Add more fill-ups to see patterns")
            } else {
                Chart(dayOfWeekData) { point in
                    BarMark(
                        x: .value("Day", point.category),
                        y: .value("Count", point.value)
                    )
                    .foregroundStyle(.orange)
                }
                .aspectRatio(2, contentMode: .fit)
            }
        }
    }

    // MARK: - Drive Mode Details Content

    private func driveModeDetailsContent(summary: FuelSummary) -> some View {
        Group {
            if summary.driveModeBreakdown.isEmpty {
                Text("Log different drive modes to compare performance")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(FuelEntry.DriveMode.allCases) { mode in
                    if let breakdown = summary.driveModeBreakdown[mode] {
                        LabeledContent {
                            VStack(alignment: .trailing) {
                                if let lPer100 = breakdown.lPer100KM {
                                    Text(settings.formatEfficiency(lPer100))
                                        .font(.headline)
                                }
                                if let cost = breakdown.costPerKM {
                                    Text(settings.formatCostPerDistance(cost))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(settings.formatDistance(breakdown.distance))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } label: {
                            Label(mode.rawValue, systemImage: iconForMode(mode))
                                .foregroundStyle(colorForMode(mode))
                        }
                    }
                }
            }
        }
    }

    private func colorForMode(_ mode: FuelEntry.DriveMode) -> Color {
        switch mode {
        case .eco: return .green
        case .normal: return .blue
        case .sport: return .red
        }
    }

    private func iconForMode(_ mode: FuelEntry.DriveMode) -> String {
        switch mode {
        case .eco: return "leaf.fill"
        case .normal: return "car.fill"
        case .sport: return "flame.fill"
        }
    }

    // MARK: - Locked Content

    private func lockedContent(message: String) -> some View {
        VStack {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)

            Button("Unlock Premium") {
                showingPaywall = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Empty Chart Label

    private func emptyChartLabel(_ message: String) -> some View {
        Label(message, systemImage: "chart.bar.xaxis")
            .foregroundStyle(.secondary)
    }

    // MARK: - Export Action

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
        .environment(PremiumManager())
}
