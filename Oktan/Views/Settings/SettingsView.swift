import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(PremiumManager.self) private var premiumManager
    @State private var showingAbout = false
    @State private var showingLanguageNote = false
    @State private var showingCSVImport = false
    @State private var showingPaywall = false
    
    var body: some View {
        NavigationStack {
            List {
                // Premium Section
                Section {
                    if premiumManager.isPremium {
                        Label("Oktan Pro Active", systemImage: "crown.fill")
                            .foregroundStyle(.indigo)
                    } else {
                        Button(action: { showingPaywall = true }) {
                            Label("Unlock Oktan Pro", systemImage: "crown")
                        }
                    }
                }
                
                // Language Section
                Section {
                    Picker("Language", selection: $settings.appLanguage) {
                        ForEach(AppSettings.AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .onChange(of: settings.appLanguage) { _, _ in
                        showingLanguageNote = true
                    }
                } header: {
                    Text("Language")
                } footer: {
                    Text("Changes will take effect after restarting the app.")
                }
                
                // Units Section
                Section {
                    Picker("Currency", selection: $settings.currencyCode) {
                        ForEach(AppSettings.supportedCurrencies, id: \.code) { currency in
                            Text("\(currency.symbol) \(currency.code) - \(currency.name)")
                                .tag(currency.code)
                        }
                    }
                    
                    Picker("Distance", selection: $settings.distanceUnit) {
                        ForEach(AppSettings.DistanceUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    
                    Picker("Volume", selection: $settings.volumeUnit) {
                        ForEach(AppSettings.VolumeUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    
                    Picker("Efficiency", selection: $settings.efficiencyUnit) {
                        ForEach(AppSettings.EfficiencyUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                } header: {
                    Text("Units & Currency")
                } footer: {
                    Text("Choose your preferred units for tracking fuel consumption.")
                }
                
                // Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(AppSettings.AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    NotificationLink()
                }
                
                // Data Section
                Section {
                    Button(action: { showingCSVImport = true }) {
                        Label("Import from CSV", systemImage: "square.and.arrow.down")
                    }
                    
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("Data Management", systemImage: "externaldrive")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Import data from other fuel tracking apps or manage your existing data.")
                }
                
                // About Section
                Section {
                    Button(action: { showingAbout = true }) {
                        HStack {
                            Label("About Oktan", systemImage: "info.circle")
                            Spacer()
                            Text(appVersion)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Link(destination: URL(string: "https://github.com/ustunfatih/oktan")!) {
                        Label("GitHub Repository", systemImage: "link")
                    }
                    
                    Link(destination: URL(string: "mailto:support@oktan.app")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingCSVImport) {
                CSVImportView()
            }
            .alert("Restart Required", isPresented: $showingLanguageNote) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please restart the app for language changes to take effect.")
            }
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @EnvironmentObject private var repository: FuelRepository
    @State private var showingExportSheet = false
    @State private var showingResetConfirmation = false
    @State private var csvFileURL: URL?
    
    var body: some View {
        List {
            Section("Export") {
                Button(action: exportData) {
                    Label("Export to CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(repository.entries.isEmpty)
            }
            
            Section {
                Button(role: .destructive, action: { showingResetConfirmation = true }) {
                    Label("Delete All Data", systemImage: "trash")
                }
            } footer: {
                Text("This will permanently delete all fuel entries. This action cannot be undone.")
            }
        }
        .navigationTitle("Data Management")
        .sheet(isPresented: $showingExportSheet) {
            if let url = csvFileURL {
                ShareSheet(items: [url])
            }
        }
        .confirmationDialog("Delete All Data?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                for entry in repository.entries {
                    repository.delete(entry)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(repository.entries.count) fuel entries. This action cannot be undone.")
        }
    }
    
    private func exportData() {
        csvFileURL = repository.createCSVFile()
        if csvFileURL != nil {
            showingExportSheet = true
        }
    }
}

// MARK: - About View (Bible Compliant)
// Removed: LinearGradient, fixed font size .system(size: 60)

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // App Header Section
                Section {
                    VStack {
                        Image(systemName: "fuelpump.circle.fill")
                            .font(.largeTitle) // System font - Bible compliant
                            .foregroundStyle(.tint)

                        Text("Oktan")
                            .font(.largeTitle.bold())

                        Text("Track your fuel. Optimize your drive.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding() // No numeric value - Bible compliant
                }
                .listRowBackground(Color.clear)

                // Features Section
                Section {
                    featureRow(icon: "fuelpump.fill", title: "Fuel Tracking", description: "Log every fill-up with detailed information")
                    featureRow(icon: "chart.line.uptrend.xyaxis", title: "Analytics", description: "Track efficiency trends and costs over time")
                    featureRow(icon: "car.fill", title: "Multiple Cars", description: "Manage fuel logs for all your vehicles")
                    featureRow(icon: "icloud.fill", title: "Cloud Sync", description: "Keep your data synced across devices")
                } header: {
                    Text("Features")
                }

                // Footer
                Section {
                    Text("Made with love for drivers")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func featureRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        Label {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.tint) // System tint - Bible compliant
        }
    }
}

#Preview {
    SettingsView(settings: AppSettings())
        .environmentObject(FuelRepository())
        .environment(NotificationService())
}

// MARK: - Notification Link Helper

private struct NotificationLink: View {
    @Environment(NotificationService.self) private var notificationService
    
    var body: some View {
        NavigationLink {
            NotificationSettingsView(notificationService: notificationService)
        } label: {
            HStack {
                Label("Reminders", systemImage: "bell.badge")
                Spacer()
                if notificationService.reminderFrequency != .never {
                    Text(notificationService.reminderFrequency.displayName)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    Text("Off")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
    }
}
