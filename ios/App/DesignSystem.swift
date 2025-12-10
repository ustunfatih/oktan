import SwiftUI

enum DesignSystem {
    enum ColorPalette {
        static let primaryBlue = Color(hex: "007AFF")
        static let deepPurple = Color(hex: "5856D6")
        static let successGreen = Color(hex: "34C759")
        static let warningOrange = Color(hex: "FF9500")
        static let errorRed = Color(hex: "FF3B30")
        static let label = Color(hex: "1D1D1F")
        static let secondaryLabel = Color(hex: "6E6E73")
        static let background = Color(hex: "F5F5F7")
        static let glassTint = Color(hex: "E8F4FD")
    }

    enum Spacing {
        static let xsmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xlarge: CGFloat = 32
    }

    enum CornerRadius {
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
