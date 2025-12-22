import Charts
import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var repository: FuelRepository
    @State private var showingExportSheet = false
    @State private var csvFileURL: URL?

    var body: some View {
        NavigationStack {
            let summary = repository.summary()

            List {
                Section {
                    metricsContent(summary: summary)
                } header: {
                    Text("At a Glance")
                }

                Section {
                    efficiencyChartContent()
                } header: {
                    Text("Efficiency Trend")
                }

                Section {
                    costChartContent()
                } header: {
                    Text("Cost per km")
                }

                Section {
                    driveModeBreakdownContent(summary: summary)
                } header: {
                    Text("Drive Modes")
                }

                Section {
                    exportContent()
                } header: {
                    Text("Export")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Reports")
            .sheet(isPresented: $showingExportSheet) {
                if let url = csvFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func metricsContent(summary: FuelSummary) -> some View {
        Group {
            LabeledContent("Total distance", value: "\(summary.totalDistance, specifier: "%.0f") km")
            LabeledContent("Total fuel", value: "\(summary.totalLiters, specifier: "%.1f") L")
            LabeledContent("Total cost", value: summary.totalCost.formatted(.currency(code: AppConfiguration.currencyCode)))
            LabeledContent(
                "Recent efficiency",
                value: summary.recentAverageLitersPer100KM.map { "\($0, specifier: "%.2f") L/100km" } ?? "N/A"
            )
        }
    }

    private func efficiencyChartContent() -> some View {
        let entries = repository.entries.compactMap { entry -> FuelEntry? in
            guard entry.litersPer100KM != nil else { return nil }
            return entry
        }

        return Group {
            if entries.isEmpty {
                emptyChartLabel("Add odometer start/end to chart efficiency")
            } else {
                Chart(entries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("L/100km", entry.litersPer100KM ?? 0)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .month)) }
                .aspectRatio(1.5, contentMode: .fit)
            }
        }
    }

    private func costChartContent() -> some View {
        let entries = repository.entries.compactMap { entry -> FuelEntry? in
            guard entry.costPerKM != nil else { return nil }
            return entry
        }

        return Group {
            if entries.isEmpty {
                emptyChartLabel("Track odometer values to unlock cost insights")
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("\(AppConfiguration.currencyCode)/km", entry.costPerKM ?? 0)
                    )
                    .foregroundStyle(.purple)
                }
                .aspectRatio(1.5, contentMode: .fit)
            }
        }
    }

    private func driveModeBreakdownContent(summary: FuelSummary) -> some View {
        Group {
            if summary.driveModeBreakdown.isEmpty {
                emptyChartLabel("Log drive modes to see performance deltas")
            } else {
                ForEach(FuelEntry.DriveMode.allCases) { mode in
                    if let breakdown = summary.driveModeBreakdown[mode] {
                        LabeledContent {
                            VStack(alignment: .trailing) {
                                if let lPer100 = breakdown.lPer100KM {
                                    Text("\(lPer100, specifier: "%.2f") L/100km")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let cost = breakdown.costPerKM {
                                    Text("\(cost, specifier: "%.3f") \(AppConfiguration.currencyCode)/km")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } label: {
                            Text(mode.rawValue)
                        }
                    }
                }
            }
        }
    }

    private func exportContent() -> some View {
        Group {
            Button(action: exportData) {
                Label("Export to CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(repository.entries.isEmpty)

            if repository.entries.isEmpty {
                Text("Add some fill-ups to enable export")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exportData() {
        csvFileURL = repository.createCSVFile()
        if csvFileURL != nil {
            showingExportSheet = true
        }
    }

    private func emptyChartLabel(_ message: String) -> some View {
        Label(message, systemImage: "chart.bar.xaxis")
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ReportsView()
        .environmentObject(FuelRepository())
}
