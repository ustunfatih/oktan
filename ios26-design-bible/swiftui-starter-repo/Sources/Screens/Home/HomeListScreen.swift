import SwiftUI

struct HomeListScreen: View {
    var body: some View {
        ListShell(title: "Home") {
            Section("Examples") {
                NavigationLink("Detail Example", value: "detailExample")
                NavigationLink("Form Example", value: "formExample")
            }
        }
        .navigationDestination(for: String.self) { route in
            switch route {
            case "detailExample":
                DetailScreen(title: "Detail Example")
            case "formExample":
                FormScreen()
            default:
                DetailScreen(title: "Unknown")
            }
        }
    }
}
