import SwiftUI

struct DetailScreen: View {
    let title: String

    var body: some View {
        DetailShell(title: title) {
            Section("Details") {
                Text("This screen is intentionally plain and system-driven.")
                Text("No numeric padding. No fixed frames. No custom colors.")
            }
        }
    }
}
