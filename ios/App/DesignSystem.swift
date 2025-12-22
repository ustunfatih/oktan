import SwiftUI

// MARK: - iOS 26 Design Bible Compliant Design System
// Only system colors and system spacing are allowed.

enum BibleColors {
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let destructive = Color.red
    static let success = Color.green
    static let warning = Color.orange
    static let accent = Color.accentColor
    static let background = Color(uiColor: .systemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
}

extension View {
    func systemCard() -> some View {
        self
            .background(.ultraThinMaterial)
    }
}
