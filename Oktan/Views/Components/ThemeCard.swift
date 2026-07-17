import SwiftUI

/// A mini theme preview card for the appearance picker: swatch dots, a sample
/// stat rendered in the theme's display font, and a selection indicator.
struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    swatch(theme.accent)
                    swatch(theme.secondaryAccent)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.accent)
                    }
                }

                Text("9.9")
                    .font(theme.displayFont(relativeTo: .title))
                    .foregroundStyle(.primary)
                + Text(" L/100")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(theme.tagline)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceTint, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? theme.accent : Color.primary.opacity(0.08),
                                  lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.name) theme, \(theme.tagline)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func swatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
        ForEach(Theme.all) { theme in
            ThemeCard(theme: theme, isSelected: theme.id == "petrol") {}
        }
    }
    .padding()
}
