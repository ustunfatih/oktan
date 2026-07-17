import SwiftUI

// MARK: - Design System
// Semantic color references built on system colors.
// (The theme engine planned for the redesign will supersede AccentTheme.)

enum BibleColors {
    // Use semantic system colors only
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let destructive = Color.red
    static let success = Color.green
    static let warning = Color.orange
    static let accent = Color.accentColor

    // System UI colors
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let label = Color(uiColor: .label)
    static let secondaryLabel = Color(uiColor: .secondaryLabel)

    /// Dynamic gradient based on a color
    static func primaryGradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Lively mesh-like gradient for hero cards
    static func heroGradient(for color: Color) -> some ShapeStyle {
        LinearGradient(
            colors: [color.opacity(0.8), color.opacity(0.4), color.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - App Themes (Accent Colors)

    struct AccentTheme: Identifiable, Hashable {
        let id: String
        let name: String
        let color: Color
        
        static let themes: [AccentTheme] = [
            AccentTheme(id: "blue", name: "Classic Blue", color: .blue),
            AccentTheme(id: "indigo", name: "Royal Indigo", color: .indigo),
            AccentTheme(id: "teal", name: "Modern Teal", color: .teal),
            AccentTheme(id: "mint", name: "Fresh Mint", color: .mint),
            AccentTheme(id: "orange", name: "Energetic Orange", color: .orange),
            AccentTheme(id: "pink", name: "Vibrant Pink", color: .pink)
        ]
    }
}

// MARK: - DesignSystem Namespace for Legacy Compatibility

enum DesignSystem {
    /// Color palette built on system colors
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

}

// MARK: - View Extensions

extension View {
    /// Apply system material background appropriate for cards/sections.
    /// Uses .ultraThinMaterial which is a system-provided blur effect.
    func systemCard() -> some View {
        self
            .background(.ultraThinMaterial)
    }

    /// Apply system grouped background
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
    
    /// Apply a lively entrance animation to a view
    func livelyEntrance(delay: Double = 0) -> some View {
        self.modifier(LivelyEntranceModifier(delay: delay))
    }
}

private struct LivelyEntranceModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isVisible ? 0 : 20)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.bouncy.delay(delay)) {
                    isVisible = true
                }
            }
    }
}
