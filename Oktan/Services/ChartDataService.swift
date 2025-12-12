import Foundation

/// Service for aggregating and processing chart data
enum ChartDataService {
    
    // MARK: - Types
    
    /// Data point for time-based charts
    struct TimeSeriesPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let label: String?
        
        init(date: Date, value: Double, label: String? = nil) {
            self.date = date
            self.value = value
            self.label = label
        }
    }
    
    /// Data point for comparison charts
    struct ComparisonPoint: Identifiable {
        let id = UUID()
        let category: String
        let value: Double
        let color: String
    }
    
    /// Monthly aggregated data
    struct MonthlyData: Identifiable {
        let id = UUID()
        let month: Date
        let monthLabel: String
        let totalDistance: Double
        let totalLiters: Double
        let totalCost: Double
        let averageEfficiency: Double?
        let averageCostPerKM: Double?
        let fillUpCount: Int
    }
    
    /// Period comparison data
    struct PeriodComparison {
        let currentPeriod: MonthlyData?
        let previousPeriod: MonthlyData?
        
        var efficiencyChange: Double? {
            guard let current = currentPeriod?.averageEfficiency,
                  let previous = previousPeriod?.averageEfficiency,
                  previous > 0 else { return nil }
            return ((current - previous) / previous) * 100
        }
        
        var costChange: Double? {
            guard let current = currentPeriod?.averageCostPerKM,
                  let previous = previousPeriod?.averageCostPerKM,
                  previous > 0 else { return nil }
            return ((current - previous) / previous) * 100
        }
    }
    
    // MARK: - Efficiency Data
    
    /// Gets efficiency trend data points
    static func efficiencyTrend(from entries: [FuelEntry]) -> [TimeSeriesPoint] {
        entries
            .filter { $0.litersPer100KM != nil }
            .sorted { $0.date < $1.date }
            .map { TimeSeriesPoint(date: $0.date, value: $0.litersPer100KM!, label: $0.gasStation) }
    }
    
    /// Gets rolling average efficiency (smoothed trend line)
    static func rollingAverageEfficiency(from entries: [FuelEntry], windowSize: Int = 3) -> [TimeSeriesPoint] {
        let sorted = entries
            .filter { $0.litersPer100KM != nil }
            .sorted { $0.date < $1.date }
        
        guard sorted.count >= windowSize else { return [] }
        
        var result: [TimeSeriesPoint] = []
        for i in (windowSize - 1)..<sorted.count {
            let window = sorted[(i - windowSize + 1)...i]
            let avg = window.compactMap { $0.litersPer100KM }.reduce(0, +) / Double(windowSize)
            result.append(TimeSeriesPoint(date: sorted[i].date, value: avg))
        }
        return result
    }
    
    // MARK: - Cost Data
    
    /// Gets cost per km trend data
    static func costPerKMTrend(from entries: [FuelEntry]) -> [TimeSeriesPoint] {
        entries
            .filter { $0.costPerKM != nil }
            .sorted { $0.date < $1.date }
            .map { TimeSeriesPoint(date: $0.date, value: $0.costPerKM!) }
    }
    
    /// Gets total cost per month
    static func monthlyCostTrend(from entries: [FuelEntry]) -> [TimeSeriesPoint] {
        let monthly = aggregateMonthly(from: entries)
        return monthly.map { TimeSeriesPoint(date: $0.month, value: $0.totalCost, label: $0.monthLabel) }
    }
    
    /// Gets weekly spending totals
    static func weeklySpending(from entries: [FuelEntry]) -> [TimeSeriesPoint] {
        let calendar = Calendar.current
        var weeklyTotals: [Date: Double] = [:]
        
        for entry in entries {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start ?? entry.date
            weeklyTotals[weekStart, default: 0] += entry.totalCost
        }
        
        return weeklyTotals
            .map { TimeSeriesPoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    // MARK: - Drive Mode Analysis
    
    /// Gets efficiency comparison by drive mode
    static func driveModeComparison(from entries: [FuelEntry]) -> [ComparisonPoint] {
        let modes = Dictionary(grouping: entries.filter { $0.litersPer100KM != nil }) { $0.driveMode }
        
        return FuelEntry.DriveMode.allCases.compactMap { mode -> ComparisonPoint? in
            guard let modeEntries = modes[mode], !modeEntries.isEmpty else { return nil }
            
            let avgEfficiency = modeEntries.compactMap { $0.litersPer100KM }.reduce(0, +) / Double(modeEntries.count)
            
            let color: String
            switch mode {
            case .eco: color = "green"
            case .normal: color = "blue"
            case .sport: color = "orange"
            }
            
            return ComparisonPoint(category: mode.rawValue, value: avgEfficiency, color: color)
        }
    }
    
    // MARK: - Monthly Aggregation
    
    /// Aggregates entries by month
    static func aggregateMonthly(from entries: [FuelEntry]) -> [MonthlyData] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        var monthlyGroups: [Date: [FuelEntry]] = [:]
        
        for entry in entries {
            let components = calendar.dateComponents([.year, .month], from: entry.date)
            guard let monthStart = calendar.date(from: components) else { continue }
            monthlyGroups[monthStart, default: []].append(entry)
        }
        
        return monthlyGroups.map { month, monthEntries in
            let distance = monthEntries.compactMap { $0.distance }.reduce(0, +)
            let liters = monthEntries.reduce(0) { $0 + $1.totalLiters }
            let cost = monthEntries.reduce(0) { $0 + $1.totalCost }
            
            let avgEfficiency: Double?
            if distance > 0 {
                avgEfficiency = (liters / distance) * 100
            } else {
                avgEfficiency = nil
            }
            
            let avgCostPerKM: Double?
            if distance > 0 {
                avgCostPerKM = cost / distance
            } else {
                avgCostPerKM = nil
            }
            
            return MonthlyData(
                month: month,
                monthLabel: formatter.string(from: month),
                totalDistance: distance,
                totalLiters: liters,
                totalCost: cost,
                averageEfficiency: avgEfficiency,
                averageCostPerKM: avgCostPerKM,
                fillUpCount: monthEntries.count
            )
        }
        .sorted { $0.month < $1.month }
    }
    
    /// Gets month-over-month comparison
    static func monthOverMonthComparison(from entries: [FuelEntry]) -> PeriodComparison {
        let monthly = aggregateMonthly(from: entries)
        guard monthly.count >= 1 else { return PeriodComparison(currentPeriod: nil, previousPeriod: nil) }
        
        let current = monthly.last
        let previous = monthly.count >= 2 ? monthly[monthly.count - 2] : nil
        
        return PeriodComparison(currentPeriod: current, previousPeriod: previous)
    }
    
    // MARK: - Fill-up Frequency
    
    /// Calculates average days between fill-ups
    static func averageDaysBetweenFillups(from entries: [FuelEntry]) -> Double? {
        let sorted = entries.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return nil }
        
        var totalDays: Int = 0
        for i in 1..<sorted.count {
            let days = Calendar.current.dateComponents([.day], from: sorted[i-1].date, to: sorted[i].date).day ?? 0
            totalDays += days
        }
        
        return Double(totalDays) / Double(sorted.count - 1)
    }
    
    /// Gets fill-up frequency by day of week
    static func fillupsByDayOfWeek(from entries: [FuelEntry]) -> [ComparisonPoint] {
        let calendar = Calendar.current
        let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        
        var counts: [Int: Int] = [:]
        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.date)
            counts[weekday, default: 0] += 1
        }
        
        return (1...7).map { weekday in
            ComparisonPoint(
                category: weekdays[weekday - 1],
                value: Double(counts[weekday] ?? 0),
                color: "blue"
            )
        }
    }
    
    // MARK: - Year-over-Year
    
    /// Gets year-over-year comparison for efficiency
    static func yearOverYearEfficiency(from entries: [FuelEntry]) -> [(year: Int, months: [TimeSeriesPoint])] {
        let calendar = Calendar.current
        var yearGroups: [Int: [FuelEntry]] = [:]
        
        for entry in entries {
            let year = calendar.component(.year, from: entry.date)
            yearGroups[year, default: []].append(entry)
        }
        
        return yearGroups.map { year, yearEntries in
            let monthly = aggregateMonthly(from: yearEntries)
            let points = monthly.compactMap { month -> TimeSeriesPoint? in
                guard let efficiency = month.averageEfficiency else { return nil }
                return TimeSeriesPoint(date: month.month, value: efficiency, label: month.monthLabel)
            }
            return (year: year, months: points)
        }
        .sorted { $0.year < $1.year }
    }
    
    // MARK: - Insights
    
    /// Generates insights based on the data
    static func generateInsights(from entries: [FuelEntry]) -> [String] {
        var insights: [String] = []
        
        let completed = entries.filter { $0.litersPer100KM != nil }
        
        // Best/worst efficiency
        if let best = completed.min(by: { ($0.litersPer100KM ?? 0) < ($1.litersPer100KM ?? 0) }),
           let worst = completed.max(by: { ($0.litersPer100KM ?? 0) < ($1.litersPer100KM ?? 0) }),
           let bestEff = best.litersPer100KM,
           let worstEff = worst.litersPer100KM {
            insights.append("Best efficiency: \(String(format: "%.1f", bestEff)) L/100km on \(best.date.formatted(date: .abbreviated, time: .omitted))")
            insights.append("Worst efficiency: \(String(format: "%.1f", worstEff)) L/100km on \(worst.date.formatted(date: .abbreviated, time: .omitted))")
        }
        
        // Drive mode comparison
        let modeComparison = driveModeComparison(from: entries)
        if modeComparison.count > 1,
           let best = modeComparison.min(by: { $0.value < $1.value }),
           let worst = modeComparison.max(by: { $0.value < $1.value }) {
            let savings = ((worst.value - best.value) / worst.value) * 100
            if savings > 5 {
                insights.append("\(best.category) mode is \(String(format: "%.0f", savings))% more efficient than \(worst.category)")
            }
        }
        
        // Average days between fill-ups
        if let avgDays = averageDaysBetweenFillups(from: entries) {
            insights.append("You fill up every \(String(format: "%.0f", avgDays)) days on average")
        }
        
        // Monthly spending trend
        let monthlyData = aggregateMonthly(from: entries)
        if monthlyData.count >= 2 {
            let current = monthlyData.last!
            let previous = monthlyData[monthlyData.count - 2]
            let change = ((current.totalCost - previous.totalCost) / previous.totalCost) * 100
            if abs(change) > 10 {
                let direction = change > 0 ? "increased" : "decreased"
                insights.append("This month's spending \(direction) by \(String(format: "%.0f", abs(change)))%")
            }
        }
        
        return insights
    }
}
