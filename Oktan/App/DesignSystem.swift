import SwiftUI

// MARK: - iOS 26 Design Bible Compliant Design System
// This file contains ONLY system colors and no numeric inference.
// All spacing, radii, and chrome are handled by system defaults.
//
// FORBIDDEN (Article II - No Numeric Inference):
// - Explicit spacing values (4, 8, 16, 24, etc.)
// - Explicit corner radius values
// - Explicit shadow definitions
// - Hex colors (Color(hex: "..."))
// - RGB colors (Color(red:green:blue:))
//
// ALLOWED:
// - System semantic colors (Color.primary, .secondary, .red, .green, etc.)
// - System UI colors (Color(uiColor: .systemBackground))
// - System materials (.ultraThinMaterial, .regularMaterial, etc.)
// - .padding() without arguments
// - .background(.fill) for system backgrounds

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

    // System UI colors (acceptable per Bible)
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let label = Color(uiColor: .label)
    static let secondaryLabel = Color(uiColor: .secondaryLabel)
}

// MARK: - DesignSystem Namespace for Legacy Compatibility
// This provides a migration path for existing code while remaining Bible-compliant

enum DesignSystem {
    /// Bible-compliant color palette using ONLY system colors
    enum ColorPalette {
        // Primary semantic colors
        static let primaryBlue = Color.blue          // System blue
        static let deepPurple = Color.purple         // System purple
        static let successGreen = Color.green        // System green
        static let warningOrange = Color.orange      // System orange
        static let errorRed = Color.red              // System red

        // Label colors (system)
        static let label = Color(uiColor: .label)
        static let secondaryLabel = Color(uiColor: .secondaryLabel)

        // Background colors (system)
        static let background = Color(uiColor: .systemGroupedBackground)
    }

    // REMOVED: Spacing enum (Article II violation)
    // REMOVED: CornerRadius enum (Article II violation)
    // REMOVED: Shadows enum (Article II violation)
}

// MARK: - Bible-Compliant View Extensions

extension View {
    /// Apply system material background appropriate for cards/sections.
    /// Uses .ultraThinMaterial which is a system-provided blur effect.
    func systemCard() -> some View {
        self
            .background(.ultraThinMaterial)
    }

    /// Apply system grouped background - Bible compliant
    func systemGroupedBackground() -> some View {
        self
            .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    /// Apply system fill background with system corner radius
    /// Uses .fill which applies system-appropriate styling
    func systemCardStyle() -> some View {
        self
            .padding()
            .background(.fill)
    }
}
