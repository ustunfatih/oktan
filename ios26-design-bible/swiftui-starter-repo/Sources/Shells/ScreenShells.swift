import SwiftUI

/// Approved shells. Screens should compose one of these as the outermost container.
/// No numeric padding or fixed frames are permitted in shells.

struct ListShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        List { content() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
    }
}

struct DetailShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        List { content() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct FormShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        Form { content() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct SearchShell<Content: View>: View {
    let title: String
    @Binding var query: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        List { content() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query)
    }
}
