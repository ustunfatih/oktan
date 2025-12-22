import SwiftUI

@main
struct OktanApp: App {
    @StateObject private var repository = FuelRepository()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(repository)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var repository: FuelRepository
    @SceneStorage("selectedTab") private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TrackingView()
                .tabItem {
                    Label("Tracking", systemImage: "fuelpump.fill")
                }
                .tag(0)

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }
                .tag(1)
        }
        .onAppear { repository.bootstrapIfNeeded() }
    }
}
