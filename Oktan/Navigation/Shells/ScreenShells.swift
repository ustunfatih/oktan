import SwiftUI

// MARK: - iOS 26 Design Bible Compliant Screen Shells
// These shells enforce proper navigation patterns and system styling.
//
// Every screen MUST use one of these shells:
// - ListShell: For list-based screens (root tabs, settings, etc.)
// - DetailShell: For pushed detail views (inline title)
// - FormShell: For form-based input (edit, create)
// - SearchShell: For searchable lists
//
// Rules (per Constitution):
// - No numeric padding/spacing
// - No custom corner radius
// - No custom navigation chrome
// - Large title for root screens, inline for pushed

// MARK: - ListShell

/// Shell for list-based screens with large navigation title.
/// Use for root tab screens and primary list views.
struct ListShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        List {
            content()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - DetailShell

/// Shell for pushed detail views with inline navigation title.
/// Use for secondary screens that are pushed onto the navigation stack.
struct DetailShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        List {
            content()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FormShell

/// Shell for form-based input screens with inline navigation title.
/// Use for create/edit flows that need Form styling.
struct FormShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        Form {
            content()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - SearchShell

/// Shell for searchable list screens with large navigation title.
/// Use for screens that need search functionality.
struct SearchShell<Content: View>: View {
    let title: String
    @Binding var query: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        List {
            content()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query)
    }
}

// MARK: - ScrollShell (For special cases like charts)

/// Shell for scrollable content that cannot use List.
/// Use ONLY when List is not appropriate (e.g., chart-heavy screens).
/// This is an exception that should be documented in TRACEABILITY_MATRIX.md.
struct ScrollShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .padding() // System padding only, no numeric value
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Previews

#Preview("ListShell") {
    NavigationStack {
        ListShell(title: "Home") {
            Section("Examples") {
                Text("Item 1")
                Text("Item 2")
            }
        }
    }
}

#Preview("DetailShell") {
    NavigationStack {
        DetailShell(title: "Detail") {
            Section {
                Text("Detail content")
            }
        }
    }
}

#Preview("FormShell") {
    NavigationStack {
        FormShell(title: "Edit") {
            Section("Form Fields") {
                TextField("Name", text: .constant(""))
                Toggle("Active", isOn: .constant(true))
            }
        }
    }
}

#Preview("SearchShell") {
    NavigationStack {
        SearchShell(title: "Search", query: .constant("")) {
            Section {
                Text("Search results appear here")
            }
        }
    }
}
