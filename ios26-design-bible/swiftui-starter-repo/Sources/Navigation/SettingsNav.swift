import SwiftUI

struct SettingsNav: View {
    var body: some View {
        NavigationStack {
            SettingsScreen()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
