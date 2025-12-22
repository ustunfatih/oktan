import SwiftUI

// MARK: - iOS 26 Design Bible Compliant Root Scaffold
// This is the main tab container with state restoration.
//
// Compliance:
// - Uses @SceneStorage for tab persistence (Article VI)
// - No .tint() or color overrides (Article III)
// - System TabView with system styling

/// The root scaffold containing the main tab navigation.
/// Tab selection is persisted via @SceneStorage.
struct RootScaffold: View {
    @EnvironmentObject private var repository: FuelRepository
    @Environment(NotificationService.self) private var notificationService

    /// Persisted tab selection - survives app termination
    @SceneStorage("selectedTab") private var selectedTab: String = "home"

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeNav()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag("home")

            TrackingNav()
                .tabItem {
                    Label("Tracking", systemImage: "fuelpump")
                }
                .tag("tracking")

            ReportsNav()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar")
                }
                .tag("reports")

            ProfileNav()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag("profile")

            SettingsNav()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag("settings")
        }
        // NO .tint() - use system accent color (Bible compliance)
        .onChange(of: notificationService.shouldShowAddFuel) { _, shouldShow in
            if shouldShow {
                selectedTab = "tracking"
            }
        }
    }
}

// MARK: - Navigation Wrappers

/// Home tab navigation wrapper with path persistence
struct HomeNav: View {
    @SceneStorage("homeNavPath") private var navPathData: Data?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen()
                .onAppear { restorePath() }
                .onChange(of: path) { _, _ in savePath() }
        }
    }

    private func restorePath() {
        guard let data = navPathData,
              let decoded = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data) else { return }
        path = NavigationPath(decoded)
    }

    private func savePath() {
        guard let representation = path.codable else {
            navPathData = nil
            return
        }
        navPathData = try? JSONEncoder().encode(representation)
    }
}

/// Tracking tab navigation wrapper with path persistence
struct TrackingNav: View {
    @SceneStorage("trackingNavPath") private var navPathData: Data?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            TrackingScreen()
                .onAppear { restorePath() }
                .onChange(of: path) { _, _ in savePath() }
        }
    }

    private func restorePath() {
        guard let data = navPathData,
              let decoded = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data) else { return }
        path = NavigationPath(decoded)
    }

    private func savePath() {
        guard let representation = path.codable else {
            navPathData = nil
            return
        }
        navPathData = try? JSONEncoder().encode(representation)
    }
}

/// Reports tab navigation wrapper with path persistence
struct ReportsNav: View {
    @SceneStorage("reportsNavPath") private var navPathData: Data?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ReportsScreen()
                .onAppear { restorePath() }
                .onChange(of: path) { _, _ in savePath() }
        }
    }

    private func restorePath() {
        guard let data = navPathData,
              let decoded = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data) else { return }
        path = NavigationPath(decoded)
    }

    private func savePath() {
        guard let representation = path.codable else {
            navPathData = nil
            return
        }
        navPathData = try? JSONEncoder().encode(representation)
    }
}

/// Profile tab navigation wrapper with path persistence
struct ProfileNav: View {
    @SceneStorage("profileNavPath") private var navPathData: Data?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ProfileScreen()
                .onAppear { restorePath() }
                .onChange(of: path) { _, _ in savePath() }
        }
    }

    private func restorePath() {
        guard let data = navPathData,
              let decoded = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data) else { return }
        path = NavigationPath(decoded)
    }

    private func savePath() {
        guard let representation = path.codable else {
            navPathData = nil
            return
        }
        navPathData = try? JSONEncoder().encode(representation)
    }
}

/// Settings tab navigation wrapper with path persistence
struct SettingsNav: View {
    @Environment(AppSettings.self) private var appSettings
    @SceneStorage("settingsNavPath") private var navPathData: Data?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            SettingsScreen(settings: appSettings)
                .onAppear { restorePath() }
                .onChange(of: path) { _, _ in savePath() }
        }
    }

    private func restorePath() {
        guard let data = navPathData,
              let decoded = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data) else { return }
        path = NavigationPath(decoded)
    }

    private func savePath() {
        guard let representation = path.codable else {
            navPathData = nil
            return
        }
        navPathData = try? JSONEncoder().encode(representation)
    }
}

// MARK: - Type Aliases for Screen Naming Convention

/// Type alias to follow Bible naming convention (*Screen.swift)
typealias HomeScreen = HomeView
typealias TrackingScreen = TrackingView
typealias ReportsScreen = ReportsView
typealias ProfileScreen = ProfileView
typealias SettingsScreen = SettingsView
