import SwiftUI

// MARK: - Root Scaffold
// The main tab container with state restoration via @SceneStorage.

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
                .livelyEntrance()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag("home")

            TrackingNav()
                .livelyEntrance()
                .tabItem {
                    Label("Tracking", systemImage: "fuelpump")
                }
                .tag("tracking")

            ReportsNav()
                .livelyEntrance()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar")
                }
                .tag("reports")

            ProfileNav()
                .livelyEntrance()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag("profile")

            SettingsNav()
                .livelyEntrance()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag("settings")
        }
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
    @SceneStorage("homeNavPathCount") private var navPathCount: Int = 0
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen()
                .onAppear { restorePath() }
                .onChange(of: path.count) { _, newCount in
                    navPathCount = newCount
                }
        }
    }

    private func restorePath() {
        // Restore path count - actual path restoration would require
        // storing hashable navigation destinations, which is not needed
        // for current app structure (no pushed screens in tabs)
        if navPathCount > 0 {
            // Path restoration not implemented as there are no pushed screens
            // in the current navigation structure
            navPathCount = 0
        }
    }
}

/// Tracking tab navigation wrapper with path persistence
struct TrackingNav: View {
    @SceneStorage("trackingNavPathCount") private var navPathCount: Int = 0
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            TrackingScreen()
                .onAppear { restorePath() }
                .onChange(of: path.count) { _, newCount in
                    navPathCount = newCount
                }
        }
    }

    private func restorePath() {
        // Restore path count - actual path restoration would require
        // storing hashable navigation destinations, which is not needed
        // for current app structure (no pushed screens in tabs)
        if navPathCount > 0 {
            navPathCount = 0
        }
    }
}

/// Reports tab navigation wrapper with path persistence
struct ReportsNav: View {
    @SceneStorage("reportsNavPathCount") private var navPathCount: Int = 0
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ReportsScreen()
                .onAppear { restorePath() }
                .onChange(of: path.count) { _, newCount in
                    navPathCount = newCount
                }
        }
    }

    private func restorePath() {
        // Restore path count - actual path restoration would require
        // storing hashable navigation destinations, which is not needed
        // for current app structure (no pushed screens in tabs)
        if navPathCount > 0 {
            navPathCount = 0
        }
    }
}

/// Profile tab navigation wrapper with path persistence
struct ProfileNav: View {
    @SceneStorage("profileNavPathCount") private var navPathCount: Int = 0
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ProfileScreen()
                .onAppear { restorePath() }
                .onChange(of: path.count) { _, newCount in
                    navPathCount = newCount
                }
        }
    }

    private func restorePath() {
        // Restore path count - actual path restoration would require
        // storing hashable navigation destinations, which is not needed
        // for current app structure (no pushed screens in tabs)
        if navPathCount > 0 {
            navPathCount = 0
        }
    }
}

/// Settings tab navigation wrapper with path persistence
struct SettingsNav: View {
    @Environment(AppSettings.self) private var appSettings
    @SceneStorage("settingsNavPathCount") private var navPathCount: Int = 0
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            SettingsScreen(settings: appSettings)
                .onAppear { restorePath() }
                .onChange(of: path.count) { _, newCount in
                    navPathCount = newCount
                }
        }
    }

    private func restorePath() {
        // Restore path count - actual path restoration would require
        // storing hashable navigation destinations, which is not needed
        // for current app structure (no pushed screens in tabs)
        if navPathCount > 0 {
            navPathCount = 0
        }
    }
}

// MARK: - Type Aliases for Screen Naming Convention

/// Legacy *Screen type aliases kept for compatibility
typealias HomeScreen = HomeView
typealias TrackingScreen = TrackingView
typealias ReportsScreen = ReportsView
typealias ProfileScreen = ProfileView
typealias SettingsScreen = SettingsView
