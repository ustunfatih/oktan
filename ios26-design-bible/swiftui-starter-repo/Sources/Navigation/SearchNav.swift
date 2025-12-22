import SwiftUI

struct SearchNav: View {
    var body: some View {
        NavigationStack {
            SearchScreen()
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
