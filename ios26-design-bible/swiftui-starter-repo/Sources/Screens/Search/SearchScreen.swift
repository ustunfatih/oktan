import SwiftUI

struct SearchScreen: View {
    @State private var query = ""
    @State private var items = ["Alpha", "Beta", "Gamma"]
    @State private var filtered: [String] = []

    var body: some View {
        SearchShell(title: "Search", query: $query) {
            if query.isEmpty {
                Section {
                    Text("Start typing to search.")
                        .foregroundStyle(.secondary)
                }
            } else if filtered.isEmpty {
                Section {
                    Text("No results.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Results") {
                    ForEach(filtered, id: \.self) { item in
                        Text(item)
                    }
                }
            }
        }
        .onChange(of: query) { _ in
            filtered = items.filter { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}
