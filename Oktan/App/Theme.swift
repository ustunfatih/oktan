import SwiftUI
import UIKit

/// An app theme: accent palette (light + dark variants baked into dynamic
/// colors), a display font for hero numbers and titles, and an optional
/// preferred color scheme (dark-first themes).
struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    /// Short tagline shown in the theme picker
    let tagline: String

    /// Primary accent (dynamic: adapts to light/dark)
    let accent: Color
    /// Secondary accent for gradients and highlights (dynamic)
    let secondaryAccent: Color
    /// Subtle surface tint used behind hero cards (dynamic)
    let surfaceTint: Color

    /// PostScript name of the bundled display font's named instance
    let displayFontName: String
    /// The theme's preferred scheme; nil follows the user/system setting
    let preferredScheme: ColorScheme?

    // MARK: - Fonts

    /// Display font scaled relative to a text style (Dynamic Type friendly).
    /// Falls back to a heavy system font if the bundled font is unavailable.
    func displayFont(relativeTo style: Font.TextStyle) -> Font {
        let baseSize = Self.baseSize(for: style)
        if UIFont(name: displayFontName, size: baseSize) != nil {
            return .custom(displayFontName, size: baseSize, relativeTo: style)
        }
        return .system(style, design: .rounded).weight(.heavy)
    }

    private static func baseSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .subheadline: return 15
        case .caption: return 12
        default: return 17
        }
    }

    // MARK: - Gradients

    /// Hero-card gradient built from the theme accents
    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.55), secondaryAccent.opacity(0.35), accent.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Definitions

    static let petrol = Theme(
        id: "petrol",
        name: "Petrol",
        tagline: "Deep green + amber",
        accent: .dynamic(light: 0x0F6E56, dark: 0x35B58F),
        secondaryAccent: .dynamic(light: 0xEF9F27, dark: 0xF4B858),
        surfaceTint: .dynamic(light: 0xEFF4F2, dark: 0x14201C),
        displayFontName: "SpaceGrotesk-Light_Bold",
        preferredScheme: nil
    )

    static let graphite = Theme(
        id: "graphite",
        name: "Graphite",
        tagline: "Pure monochrome",
        accent: .dynamic(light: 0x161616, dark: 0xE8E6E0),
        secondaryAccent: .dynamic(light: 0x6E6D68, dark: 0xB4B2A9),
        surfaceTint: .dynamic(light: 0xF5F4F0, dark: 0x1C1C1A),
        displayFontName: "ArchivoRoman-ExtraBold",
        preferredScheme: nil
    )

    static let desertFalcon = Theme(
        id: "desert",
        name: "Desert Falcon",
        tagline: "Qatar maroon + sand",
        accent: .dynamic(light: 0x8A1538, dark: 0xC24A6B),
        secondaryAccent: .dynamic(light: 0xC89B5A, dark: 0xD9B67E),
        surfaceTint: .dynamic(light: 0xF6EEDF, dark: 0x221A12),
        displayFontName: "Fraunces-SemiBold",
        preferredScheme: nil
    )

    static let midnightOctane = Theme(
        id: "midnight",
        name: "Midnight Octane",
        tagline: "Electric lime, dark-first",
        accent: .dynamic(light: 0x87B317, dark: 0xC6F432),
        secondaryAccent: .dynamic(light: 0x2298A1, dark: 0x39C5CF),
        surfaceTint: .dynamic(light: 0xF2F5E9, dark: 0x14161B),
        displayFontName: "Unbounded-Regular_SemiBold",
        preferredScheme: .dark
    )

    static let royal = Theme(
        id: "royal",
        name: "Royal",
        tagline: "Indigo + lavender",
        accent: .dynamic(light: 0x534AB7, dark: 0x9085E9),
        secondaryAccent: .dynamic(light: 0xAFA9EC, dark: 0x7F77DD),
        surfaceTint: .dynamic(light: 0xF2F1FB, dark: 0x191727),
        displayFontName: "Sora-Regular_Bold",
        preferredScheme: nil
    )

    static let pearl = Theme(
        id: "pearl",
        name: "Pearl",
        tagline: "Clean blue",
        accent: .dynamic(light: 0x185FA5, dark: 0x3987E5),
        secondaryAccent: .dynamic(light: 0x85B7EB, dark: 0x5FA0E8),
        surfaceTint: .dynamic(light: 0xF7FAFC, dark: 0x131A21),
        displayFontName: "Manrope-ExtraBold",
        preferredScheme: nil
    )

    static let all: [Theme] = [petrol, graphite, desertFalcon, midnightOctane, royal, pearl]

    static let `default` = petrol

    static func theme(id: String) -> Theme {
        all.first { $0.id == id } ?? .default
    }
}

// MARK: - Color Helpers

extension Color {
    /// A color that resolves to different hex values in light and dark mode
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
