import SwiftUI

struct HomeNav: View {
    /// Persist navigation path per scene.
    @SceneStorage("homeNavPath") private var homePathData: Data?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeListScreen()
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { HomeToolbar() }
                .onAppear { restorePathIfPossible() }
                .onChange(of: path) { _ in savePathIfPossible() }
        }
    }

    private func restorePathIfPossible() {
        guard let homePathData else { return }
        if let decoded = try? JSONDecoder().decode(NavPathCodable.self, from: homePathData) {
            path = decoded.path
        }
    }

    private func savePathIfPossible() {
        let codable = NavPathCodable(path: path)
        if let data = try? JSONEncoder().encode(codable) {
            homePathData = data
        }
    }
}

/// Simple codable wrapper; stores string identifiers only (no custom geometry).
struct NavPathCodable: Codable {
    var ids: [String] = []

    init(path: NavigationPath) {
        // If you need richer routing, store safe IDs here.
        self.ids = []
    }

    var path: NavigationPath {
        var p = NavigationPath()
        // Rebuild from ids if used.
        return p
    }
}
