import SwiftUI

// MARK: - iOS 26 Design Bible Compliant Design System
// This file contains ONLY system colors and no numeric inference.
// All spacing, radii, and chrome are handled by system defaults.

/// Bible-compliant color references using ONLY system colors.
/// No custom hex colors, no custom opacity values except where Apple API requires.
enum BibleColors {
    // Use semantic system colors only
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let destructive = Color.red
    static let success = Color.green
    static let warning = Color.orange
    static let accent = Color.accentColor
}

// MARK: - Bible-Compliant View Extensions

extension View {
    /// Apply system material background appropriate for cards/sections.
    /// Uses .ultraThinMaterial which is a system-provided blur effect.
    func systemCard() -> some View {
        self
            .background(.ultraThinMaterial)
    }
}
