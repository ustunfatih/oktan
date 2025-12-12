import SwiftUI

@main
struct OktanApp: App {
    @StateObject private var repository = FuelRepository()
    @State private var appSettings = AppSettings()
    @State private var authManager = AuthenticationManager()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView(appSettings: appSettings)
                    .environmentObject(repository)
                    .environment(appSettings)
                    .environment(authManager)
                    .opacity(showSplash ? 0 : 1)
                
                if showSplash && appSettings.showSplashAnimation {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .onAppear {
                // Check credential state on app launch
                authManager.checkCredentialState()
                
                // Dismiss splash after animation completes
                if appSettings.showSplashAnimation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSplash = false
                        }
                    }
                } else {
                    showSplash = false
                }
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var repository: FuelRepository
    var appSettings: AppSettings

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            TrackingView()
                .tabItem {
                    Label("Tracking", systemImage: "fuelpump.fill")
                }

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
            
            SettingsView(settings: appSettings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(DesignSystem.ColorPalette.primaryBlue)
        .onAppear { repository.bootstrapIfNeeded() }
    }
}
