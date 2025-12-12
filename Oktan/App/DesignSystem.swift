import SwiftUI

enum DesignSystem {
    enum ColorPalette {
        static let primaryBlue = Color.blue
        static let deepPurple = Color.indigo
        static let successGreen = Color.green
        static let warningOrange = Color.orange
        static let errorRed = Color.red
        
        static let label = Color.primary
        static let secondaryLabel = Color.secondary
        static let tertiaryLabel = Color(uiColor: .tertiaryLabel)
        
        static let background = Color(uiColor: .systemGroupedBackground)
        
        static var glassTint: Color {
            // Fallback to blue-ish tint that adapts?
            // Actually, let's use a custom logic or simply .blue.opacity(0.1) for now
            return Color.blue.opacity(0.1)
        }
    }

    enum Spacing {
        static let xsmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xlarge: CGFloat = 32
    }

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum Shadows {
        static let soft = Color.black.opacity(0.04)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassMaterial())
    }

    func metricTitleStyle() -> some View {
        font(.headline)
            .foregroundStyle(DesignSystem.ColorPalette.label)
    }

    func metricValueStyle() -> some View {
        font(.title2.weight(.semibold))
            .foregroundStyle(DesignSystem.ColorPalette.label)
    }
}

private struct GlassMaterial: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.medium)
            .background(.ultraThinMaterial)
            .background(DesignSystem.ColorPalette.glassTint.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous))
            .shadow(color: DesignSystem.Shadows.soft, radius: 8, x: 0, y: 4)
    }
}

private extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
