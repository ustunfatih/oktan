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

    var body: some View {
        TabView {
            TrackingView()
                .tabItem {
                    Label("Tracking", systemImage: "fuelpump.fill")
                }

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }
        }
        .tint(DesignSystem.ColorPalette.primaryBlue)
        .onAppear { repository.bootstrapIfNeeded() }
    }
}
