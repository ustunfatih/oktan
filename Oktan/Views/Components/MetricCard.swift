import SwiftUI

// MARK: - MetricCard
// Removed: numeric spacing, custom shapes with numeric corner radius

struct MetricCard: View {
    let title: String
    let value: String
    let trend: String?
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading) { // No spacing - uses system default
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)

            Text(value)
                .font(.title2.weight(.semibold))

            if let trend {
                Text(trend)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        // Removed: custom shape clipping with numeric corner radius
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(value). \(trend ?? "")")
    }
}

#Preview {
    MetricCard(title: "Cost / km", value: "0.18 QAR", trend: "Better than last 5 fill-ups", icon: "creditcard", tint: .blue)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
