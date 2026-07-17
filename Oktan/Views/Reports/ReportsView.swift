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
    @SceneStorage("reportsSelectedTab") private var selectedTabRaw: String = ReportTab.overview.rawValue
    
    // Interactive Chart State
    @State private var selectedDate: Date?
    @State private var selectedMonth: String?
    @State private var selectedMode: String?

    /// Chart datasets, cached so chart scrubbing (which re-renders the body on
    /// every gesture tick) doesn't re-run the aggregations each time.
    private struct ChartData {
        var insights: [String] = []
        var comparison = ChartDataService.PeriodComparison(currentPeriod: nil, previousPeriod: nil)
        var efficiencyTrend: [ChartDataService.TimeSeriesPoint] = []
        var rollingAverage: [ChartDataService.TimeSeriesPoint] = []
        var monthly: [ChartDataService.MonthlyData] = []
        var costPerKMEntries: [FuelEntry] = []
        var driveModeComparison: [ChartDataService.ComparisonPoint] = []
        var dayOfWeek: [ChartDataService.ComparisonPoint] = []
        var averageDays: Double?
    }

    @State private var chartData = ChartData()

    private func rebuildChartData() {
        let entries = repository.entries
        chartData = ChartData(
            insights: ChartDataService.generateInsights(from: entries),
            comparison: ChartDataService.monthOverMonthComparison(from: entries),
            efficiencyTrend: ChartDataService.efficiencyTrend(from: entries),
            rollingAverage: ChartDataService.rollingAverageEfficiency(from: entries),
            monthly: ChartDataService.aggregateMonthly(from: entries),
            costPerKMEntries: entries.filter { $0.costPerKM != nil },
            driveModeComparison: ChartDataService.driveModeComparison(from: entries),
            dayOfWeek: ChartDataService.fillupsByDayOfWeek(from: entries),
            averageDays: ChartDataService.averageDaysBetweenFillups(from: entries)
        )
    }
    
    enum ReportTab: String, CaseIterable {
        case overview = "Overview"
        case trends = "Trends"
        case patterns = "Patterns"
    }
    
    private var selectedTab: Binding<ReportTab> {
        Binding(
            get: { ReportTab(rawValue: selectedTabRaw) ?? .overview },
            set: { selectedTabRaw = $0.rawValue }
        )
    }

    var body: some View {
        let summary = repository.summary()

        ListShell(title: "Reports") {
                // Tab Picker Section
                Section {
                    Picker("Report Type", selection: selectedTab) {
                        ForEach(ReportTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

            // Content based on selected tab
            switch selectedTab.wrappedValue {
            case .overview:
                overviewContent(summary: summary)
            case .trends:
                trendsContent()
            case .patterns:
                patternsContent()
            }
        }
        .listStyle(.insetGrouped)
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
        .onAppear {
            rebuildChartData()
        }
        .onChange(of: repository.entries) { _, _ in
            rebuildChartData()
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

    @ViewBuilder
    private func metricsContent(summary: FuelSummary) -> some View {
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

    // MARK: - Period Comparison Content

    @ViewBuilder
    private func periodComparisonContent() -> some View {
        let comparison = chartData.comparison

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
        let insights = chartData.insights

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

    @ViewBuilder
    private func efficiencyChartContent() -> some View {
        let trendData = chartData.efficiencyTrend
        let rollingAverage = chartData.rollingAverage

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
                    
                    if let selectedDate {
                        RuleMark(x: .value("Selected", selectedDate))
                            .foregroundStyle(.gray.opacity(0.3))
                            .offset(y: -10)
                            .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit, y: .fit)) {
                                if let point = trendData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(settings.formatEfficiency(settings.convertEfficiency(point.value)))
                                            .font(.caption.bold())
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(.rect)
                                }
                            }
                    }
                }
                .chartXSelection(value: $selectedDate)
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

    // MARK: - Monthly Cost Chart Content

    @ViewBuilder
    private func monthlyCostChartContent() -> some View {
        let monthlyData = chartData.monthly

            if monthlyData.isEmpty {
                emptyChartLabel("Track fill-ups to see monthly spending")
            } else {
                Chart(monthlyData) { month in
                    BarMark(
                        x: .value("Month", month.monthLabel),
                        y: .value("Cost", month.totalCost)
                    )
                    .foregroundStyle(.purple)
                    .opacity(selectedMonth == nil || selectedMonth == month.monthLabel ? 1 : 0.5)
                }
                .chartXSelection(value: $selectedMonth)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(orientation: .verticalReversed)
                    }
                }
                .aspectRatio(1.5, contentMode: .fit)
            }
    }

    // MARK: - Cost per KM Chart Content

    @ViewBuilder
    private func costPerKMChartContent() -> some View {
        let entries = chartData.costPerKMEntries

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

    // MARK: - Drive Mode Chart Content

    @ViewBuilder
    private func driveModeChartContent() -> some View {
        let comparisonData = chartData.driveModeComparison

            if comparisonData.isEmpty {
                emptyChartLabel("Log different drive modes to compare efficiency")
            } else {
                Chart(comparisonData) { point in
                    BarMark(
                        x: .value("Mode", point.category),
                        y: .value("Efficiency", settings.convertEfficiency(point.value))
                    )
                    .foregroundStyle(colorForModeCategory(point.category))
                    .opacity(selectedMode == nil || selectedMode == point.category ? 1 : 0.5)
                    .annotation(position: .top) {
                        if selectedMode == point.category || selectedMode == nil {
                            Text(settings.formatEfficiency(settings.convertEfficiency(point.value)))
                                .font(.caption.weight(.medium))
                        }
                    }
                }
                .chartXSelection(value: $selectedMode)
                .aspectRatio(1.5, contentMode: .fit)
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

    @ViewBuilder
    private func fillupFrequencyContent() -> some View {
        let dayOfWeekData = chartData.dayOfWeek
        let averageDays = chartData.averageDays

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
