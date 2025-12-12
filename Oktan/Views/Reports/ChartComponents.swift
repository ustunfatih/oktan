import SwiftUI
import Charts

// MARK: - Interactive Efficiency Chart

struct EfficiencyTrendChart: View {
    let entries: [FuelEntry]
    let settings: AppSettings
    @State private var selectedPoint: ChartDataService.TimeSeriesPoint?
    
    private var trendData: [ChartDataService.TimeSeriesPoint] {
        ChartDataService.efficiencyTrend(from: entries)
    }
    
    private var rollingAverage: [ChartDataService.TimeSeriesPoint] {
        ChartDataService.rollingAverageEfficiency(from: entries)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Efficiency Trend")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.ColorPalette.label)
                
                Spacer()
                
                if let point = selectedPoint {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(settings.formatEfficiency(settings.convertEfficiency(point.value)))
                            .font(.headline)
                            .foregroundStyle(DesignSystem.ColorPalette.primaryBlue)
                        Text(point.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                    }
                }
            }
            
            if trendData.isEmpty {
                emptyState
            } else {
                Chart {
                    // Main data points
                    ForEach(trendData) { point in
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Efficiency", settings.convertEfficiency(point.value))
                        )
                        .foregroundStyle(DesignSystem.ColorPalette.primaryBlue.opacity(0.6))
                        .symbolSize(selectedPoint?.id == point.id ? 100 : 50)
                    }
                    
                    // Rolling average line
                    ForEach(rollingAverage) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Average", settings.convertEfficiency(point.value))
                        )
                        .foregroundStyle(DesignSystem.ColorPalette.primaryBlue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Selection indicator
                    if let selected = selectedPoint {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel.opacity(0.3))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(String(format: "%.1f", doubleValue))
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x - geometry[proxy.plotFrame!].origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            selectedPoint = trendData.min(by: {
                                                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                            })
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedPoint = nil
                                    }
                            )
                    }
                }
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Efficiency trend chart showing \(trendData.count) data points")
                .accessibilityIdentifier(AccessibilityID.reportsChart)
            }
        }
        .glassCard()
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            Text("Add odometer readings to see efficiency trends")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}

// MARK: - Monthly Cost Chart

struct MonthlyCostChart: View {
    let entries: [FuelEntry]
    let settings: AppSettings
    @State private var selectedMonth: ChartDataService.MonthlyData?
    
    private var monthlyData: [ChartDataService.MonthlyData] {
        ChartDataService.aggregateMonthly(from: entries)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Monthly Spending")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.ColorPalette.label)
                
                Spacer()
                
                if let month = selectedMonth {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(settings.formatCost(month.totalCost))
                            .font(.headline)
                            .foregroundStyle(DesignSystem.ColorPalette.deepPurple)
                        Text("\(month.fillUpCount) fill-ups")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                    }
                }
            }
            
            if monthlyData.isEmpty {
                emptyState
            } else {
                Chart(monthlyData) { month in
                    BarMark(
                        x: .value("Month", month.monthLabel),
                        y: .value("Cost", month.totalCost)
                    )
                    .foregroundStyle(
                        selectedMonth?.id == month.id
                            ? DesignSystem.ColorPalette.deepPurple
                            : DesignSystem.ColorPalette.deepPurple.opacity(0.7)
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(orientation: .verticalReversed)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let x = location.x - geometry[proxy.plotFrame!].origin.x
                                if let monthLabel: String = proxy.value(atX: x) {
                                    selectedMonth = monthlyData.first { $0.monthLabel == monthLabel }
                                }
                            }
                    }
                }
                .frame(height: 200)
            }
        }
        .glassCard()
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "chart.bar.fill")
                .font(.largeTitle)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            Text("Track fill-ups to see monthly spending")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}

// MARK: - Drive Mode Comparison Chart

struct DriveModeComparisonChart: View {
    let entries: [FuelEntry]
    let settings: AppSettings
    
    private var comparisonData: [ChartDataService.ComparisonPoint] {
        ChartDataService.driveModeComparison(from: entries)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Efficiency by Drive Mode")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DesignSystem.ColorPalette.label)
            
            if comparisonData.isEmpty {
                emptyState
            } else {
                Chart(comparisonData) { point in
                    BarMark(
                        x: .value("Mode", point.category),
                        y: .value("Efficiency", settings.convertEfficiency(point.value))
                    )
                    .foregroundStyle(colorFor(mode: point.category))
                    .cornerRadius(8)
                    .annotation(position: .top) {
                        Text(settings.formatEfficiency(settings.convertEfficiency(point.value)))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DesignSystem.ColorPalette.label)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            }
        }
        .glassCard()
    }
    
    private func colorFor(mode: String) -> Color {
        switch mode {
        case "Eco": return DesignSystem.ColorPalette.successGreen
        case "Sport": return DesignSystem.ColorPalette.warningOrange
        default: return DesignSystem.ColorPalette.primaryBlue
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "gauge.with.needle")
                .font(.largeTitle)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            Text("Log different drive modes to compare efficiency")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}

// MARK: - Fill-up Frequency Chart

struct FillupFrequencyChart: View {
    let entries: [FuelEntry]
    
    private var dayOfWeekData: [ChartDataService.ComparisonPoint] {
        ChartDataService.fillupsByDayOfWeek(from: entries)
    }
    
    private var averageDays: Double? {
        ChartDataService.averageDaysBetweenFillups(from: entries)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Fill-up Patterns")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.ColorPalette.label)
                
                Spacer()
                
                if let avg = averageDays {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Every \(Int(avg)) days")
                            .font(.headline)
                            .foregroundStyle(DesignSystem.ColorPalette.warningOrange)
                        Text("on average")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                    }
                }
            }
            
            if dayOfWeekData.isEmpty || entries.count < 3 {
                emptyState
            } else {
                Chart(dayOfWeekData) { point in
                    BarMark(
                        x: .value("Day", point.category),
                        y: .value("Count", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.ColorPalette.warningOrange, DesignSystem.ColorPalette.warningOrange.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 150)
            }
        }
        .glassCard()
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            Text("Add more fill-ups to see patterns")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }
}

// MARK: - Insights Card

struct InsightsCard: View {
    let entries: [FuelEntry]
    
    private var insights: [String] {
        ChartDataService.generateInsights(from: entries)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(DesignSystem.ColorPalette.warningOrange)
                Text("Insights")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignSystem.ColorPalette.label)
            }
            
            if insights.isEmpty {
                Text("Keep logging fill-ups to unlock insights about your driving patterns.")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    ForEach(Array(insights.prefix(4).enumerated()), id: \.offset) { _, insight in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.ColorPalette.primaryBlue)
                            Text(insight)
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.ColorPalette.label)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

// MARK: - Period Comparison Card

struct PeriodComparisonCard: View {
    let entries: [FuelEntry]
    let settings: AppSettings
    
    private var comparison: ChartDataService.PeriodComparison {
        ChartDataService.monthOverMonthComparison(from: entries)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Month-over-Month")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DesignSystem.ColorPalette.label)
            
            if let current = comparison.currentPeriod {
                HStack(spacing: DesignSystem.Spacing.medium) {
                    // Efficiency change
                    ComparisonMetric(
                        title: "Efficiency",
                        value: current.averageEfficiency.map { settings.formatEfficiency($0) } ?? "—",
                        change: comparison.efficiencyChange,
                        isLowerBetter: true
                    )
                    
                    // Cost change
                    ComparisonMetric(
                        title: "Cost/km",
                        value: current.averageCostPerKM.map { settings.formatCostPerDistance($0) } ?? "—",
                        change: comparison.costChange,
                        isLowerBetter: true
                    )
                }
            } else {
                Text("Need at least one month of data")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct ComparisonMetric: View {
    let title: String
    let value: String
    let change: Double?
    let isLowerBetter: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignSystem.ColorPalette.label)
            
            if let change = change {
                HStack(spacing: 4) {
                    Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                    Text("\(String(format: "%.0f", abs(change)))%")
                        .font(.caption)
                }
                .foregroundStyle(trendColor(for: change))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func trendColor(for change: Double) -> Color {
        let isGood = isLowerBetter ? change < 0 : change > 0
        return isGood ? DesignSystem.ColorPalette.successGreen : DesignSystem.ColorPalette.errorRed
    }
}
