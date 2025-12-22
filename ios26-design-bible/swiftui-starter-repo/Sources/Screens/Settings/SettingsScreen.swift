import SwiftUI

struct SettingsScreen: View {
    @State private var enabled = true

    var body: some View {
        ListShell(title: "Settings") {
            Section("Preferences") {
                Toggle("Enable Feature", isOn: $enabled)
            }
        }
        .navigationBarTitleDisplayMode(.large)
    }
}
