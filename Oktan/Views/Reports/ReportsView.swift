import Charts
import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var repository: FuelRepository
    @Environment(AppSettings.self) private var settings
    @Environment(PremiumManager.self) private var premiumManager
    @State private var showingExportSheet = false
    @State private var showingPaywall = false
    @State private var showingPDFError = false
    @State private var exportFileURL: URL?
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
        let entries = repository.visibleEntries
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
        case explore = "Explore"
        case trends = "Trends"
        case patterns = "Patterns"
    }

    private var selectedTab: Binding<ReportTab> {
        Binding(
            get: { ReportTab(rawValue: selectedTabRaw) ?? .overview },
            set: { selectedTabRaw = $0.rawValue }
        )
    }

    // MARK: - Time Range State

    @SceneStorage("reportsTimeRange") private var timeRangeRaw: String = AnalyticsService.TimeRange.allTime.rawValue
    @State private var periodOffset = 0

    private var timeRange: Binding<AnalyticsService.TimeRange> {
        Binding(
            get: { AnalyticsService.TimeRange(rawValue: timeRangeRaw) ?? .allTime },
            set: { timeRangeRaw = $0.rawValue }
        )
    }

    /// Entries within the selected period (and active car)
    private var scopedEntries: [FuelEntry] {
        let range = timeRange.wrappedValue
        return AnalyticsService.entries(
            repository.visibleEntries,
            in: range.interval(offset: periodOffset)
        )
    }

    var body: some View {
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
                overviewContent()
            case .explore:
                exploreContent()
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
                    .disabled(repository.visibleEntries.isEmpty)

                    Button(action: exportPDF) {
                        Label("Export to PDF", systemImage: "doc.richtext")
                    }
                    .disabled(repository.visibleEntries.isEmpty)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export options")
                .accessibilityIdentifier(AccessibilityID.reportsExportButton)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert("PDF Export Failed", isPresented: $showingPDFError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The PDF could not be created. Please try again.")
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .onAppear {
            rebuildChartData()
        }
        .onChange(of: repository.visibleEntries) { _, _ in
            rebuildChartData()
        }
    }

    // MARK: - Overview Tab

    @ViewBuilder
    private func overviewContent() -> some View {
        // Time Range Section
        Section {
            RangeSelectorView(range: timeRange, offset: $periodOffset)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }

        // Stat Tiles Section
        Section {
            StatTilesView(
                comparison: AnalyticsService.compare(
                    entries: repository.visibleEntries,
                    range: timeRange.wrappedValue,
                    offset: periodOffset
                ),
                settings: settings
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            Text("At a Glance")
        }

        // Spending Section
        Section {
            SpendingChartView(
                buckets: AnalyticsService.spendingBuckets(
                    entries: repository.visibleEntries,
                    range: timeRange.wrappedValue,
                    offset: periodOffset
                ),
                range: timeRange.wrappedValue,
                settings: settings
            )
        } header: {
            Text("Spending")
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

    // MARK: - Explore Tab

    @ViewBuilder
    private func exploreContent() -> some View {
        if premiumManager.isPremium {
            Section {
                RangeSelectorView(range: timeRange, offset: $periodOffset)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                FuelCalendarView(
                    entries: scopedEntries,
                    range: timeRange.wrappedValue,
                    offset: periodOffset,
                    settings: settings
                )
            } header: {
                Text("Fuel Calendar")
            } footer: {
                Text("Darker cells mean higher spending. Tap a cell for details.")
            }

            Section {
                StationScoreboardView(entries: scopedEntries, settings: settings)
            } header: {
                Text("Stations")
            }

            Section {
                JourneyChartView(entries: scopedEntries, settings: settings)
            } header: {
                Text("Journey")
            } footer: {
                Text("Cumulative spending over time. Drag to scrub.")
            }

            Section {
                PriceTimelineView(entries: scopedEntries, settings: settings)
            } header: {
                Text("Price History")
            }

            Section {
                EcoWhatIfView(entries: scopedEntries, settings: settings)
            } header: {
                Text("Eco What-If")
            }

            Section {
                RecordsView(entries: scopedEntries, settings: settings)
            } header: {
                Text("Records")
            }
        } else {
            Section {
                lockedContent(message: "Unlock Explore for the fuel calendar, station scoreboard, price history, and more.")
            }
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
            .disabled(repository.visibleEntries.isEmpty)

            Button(action: exportPDF) {
                Label("Export to PDF", systemImage: "doc.richtext")
            }
            .disabled(repository.visibleEntries.isEmpty)

            if repository.visibleEntries.isEmpty {
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

            if dayOfWeekData.isEmpty || repository.visibleEntries.count < 3 {
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
        exportFileURL = repository.createCSVFile()
        if exportFileURL != nil {
            showingExportSheet = true
        }
    }

    private func exportPDF() {
        exportFileURL = PDFExportService.createReportPDF(
            entries: repository.visibleEntries,
            summary: repository.summary(),
            settings: settings
        )
        if exportFileURL != nil {
            showingExportSheet = true
        } else {
            showingPDFError = true
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
