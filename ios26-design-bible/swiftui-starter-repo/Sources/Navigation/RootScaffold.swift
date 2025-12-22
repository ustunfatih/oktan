import SwiftUI

/// Root scaffold: Tab destinations must be peer-level.
/// - No custom tab bars.
/// - No icon-only tabs.
struct RootScaffold: View {
    @SceneStorage("selectedTab") private var selectedTab: String = "home"

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeNav()
                .tabItem { Label("Home", systemImage: "house") }
                .tag("home")

            SearchNav()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag("search")

            SettingsNav()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag("settings")
        }
    }
}
