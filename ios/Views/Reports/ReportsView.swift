import Charts
import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var repository: FuelRepository
    @State private var showingExportSheet = false
    @State private var csvFileURL: URL?

    var body: some View {
        NavigationStack {
            let summary = repository.summary()
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.large) {
                    metricsGrid(summary: summary)
                    efficiencyChart
                    costChart
                    driveModeBreakdown(summary: summary)
                    exportSection
                }
                .padding(DesignSystem.Spacing.large)
            }
            .background(DesignSystem.ColorPalette.background.ignoresSafeArea())
            .navigationTitle("Reports")
            .sheet(isPresented: $showingExportSheet) {
                if let url = csvFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func metricsGrid(summary: FuelSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("At a glance")
                .font(.title2.weight(.semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.medium) {
                MetricCard(
                    title: "Total distance",
                    value: summary.totalDistance.formatted(.number.precision(.fractionLength(0))).appending(" km"),
                    trend: "Based on completed odometer entries",
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    tint: DesignSystem.ColorPalette.primaryBlue
                )

                MetricCard(
                    title: "Total fuel",
                    value: summary.totalLiters.formatted(.number.precision(.fractionLength(1))).appending(" L"),
                    trend: summary.averageLitersPer100KM.map { "Avg: \($0, specifier: "%.2f") L/100km" },
                    icon: "drop.fill",
                    tint: DesignSystem.ColorPalette.deepPurple
                )

                MetricCard(
                    title: "Total cost",
                    value: summary.totalCost.formatted(.currency(code: AppConfiguration.currencyCode)),
                    trend: summary.averageCostPerKM.map { "Avg: \($0, specifier: "%.3f") \(AppConfiguration.currencyCode)/km" },
                    icon: "creditcard.fill",
                    tint: DesignSystem.ColorPalette.successGreen
                )

                MetricCard(
                    title: "Recent efficiency",
                    value: summary.recentAverageLitersPer100KM.map { "\($0, specifier: "%.2f") L/100km" } ?? "N/A",
                    trend: summary.recentAverageCostPerKM.map { "Cost: \($0, specifier: "%.3f") \(AppConfiguration.currencyCode)/km" },
                    icon: "waveform.path.ecg.rectangle",
                    tint: DesignSystem.ColorPalette.warningOrange
                )
            }
        }
    }

    private var efficiencyChart: some View {
        let entries = repository.entries.compactMap { entry -> FuelEntry? in
            guard entry.litersPer100KM != nil else { return nil }
            return entry
        }

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Efficiency trend (L/100km)")
                .font(.title2.weight(.semibold))

            if entries.isEmpty {
                placeholder("Add odometer start/end to chart efficiency")
            } else {
                Chart(entries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("L/100km", entry.litersPer100KM ?? 0)
                    )
                    .foregroundStyle(DesignSystem.ColorPalette.primaryBlue)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .month)) }
                .frame(height: 200)
                .glassCard()
            }
        }
    }

    private var costChart: some View {
        let entries = repository.entries.compactMap { entry -> FuelEntry? in
            guard entry.costPerKM != nil else { return nil }
            return entry
        }

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Cost per km")
                .font(.title2.weight(.semibold))

            if entries.isEmpty {
                placeholder("Track odometer values to unlock cost insights")
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("\(AppConfiguration.currencyCode)/km", entry.costPerKM ?? 0)
                    )
                    .foregroundStyle(DesignSystem.ColorPalette.deepPurple.gradient)
                }
                .frame(height: 200)
                .glassCard()
            }
        }
    }

    private func driveModeBreakdown(summary: FuelSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Drive modes")
                .font(.title2.weight(.semibold))

            if summary.driveModeBreakdown.isEmpty {
                placeholder("Log drive modes to see performance deltas")
            } else {
                VStack(spacing: DesignSystem.Spacing.small) {
                    ForEach(FuelEntry.DriveMode.allCases) { mode in
                        if let breakdown = summary.driveModeBreakdown[mode] {
                            HStack {
                                Text(mode.rawValue)
                                    .font(.headline)
                                Spacer()
                                if let lPer100 = breakdown.lPer100KM {
                                    Text("\(lPer100, specifier: "%.2f") L/100km")
                                        .font(.subheadline)
                                        .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                                }
                                if let cost = breakdown.costPerKM {
                                    Text("\(cost, specifier: "%.3f") \(AppConfiguration.currencyCode)/km")
                                        .font(.subheadline)
                                        .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                                }
                            }
                            .padding(.vertical, DesignSystem.Spacing.xsmall)
                        }
                    }
                }
                .glassCard()
            }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Export")
                .font(.title2.weight(.semibold))

            Button(action: exportData) {
                Label("Export to CSV", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.ColorPalette.primaryBlue)
            .disabled(repository.entries.isEmpty)
        }
    }

    private func exportData() {
        csvFileURL = repository.createCSVFile()
        if csvFileURL != nil {
            showingExportSheet = true
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ReportsView()
        .environmentObject(FuelRepository())
}
