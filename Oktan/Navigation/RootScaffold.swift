import SwiftUI

// MARK: - Root Scaffold
// The main tab container with state restoration via @SceneStorage.

/// The root scaffold containing the main tab navigation.
/// Tab selection is persisted via @SceneStorage.
struct RootScaffold: View {
    @EnvironmentObject private var repository: FuelRepository
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.scenePhase) private var scenePhase

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
        .onOpenURL { url in
            guard url.scheme == "oktan", url.host == "quick-log" else { return }
            selectedTab = "tracking"
            notificationService.shouldShowAddFuel = true
        }
        .onAppear(perform: consumeQuickLogRequest)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { consumeQuickLogRequest() }
        }
    }

    private func consumeQuickLogRequest() {
        guard QuickLogRequest.consume() else { return }
        selectedTab = "tracking"
        notificationService.shouldShowAddFuel = true
    }
}

// MARK: - Navigation Wrappers

/// Home tab navigation wrapper
struct HomeNav: View {
    var body: some View {
        NavigationStack {
            HomeScreen()
        }
    }
}

/// Tracking tab navigation wrapper
struct TrackingNav: View {
    var body: some View {
        NavigationStack {
            TrackingScreen()
        }
    }
}

/// Reports tab navigation wrapper
struct ReportsNav: View {
    var body: some View {
        NavigationStack {
            ReportsScreen()
        }
    }
}

/// Profile tab navigation wrapper
struct ProfileNav: View {
    var body: some View {
        NavigationStack {
            ProfileScreen()
        }
    }
}

/// Settings tab navigation wrapper
struct SettingsNav: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        NavigationStack {
            SettingsScreen(settings: appSettings)
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
