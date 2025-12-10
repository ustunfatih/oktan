import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let trend: String?
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)

            Text(value)
                .metricValueStyle()

            if let trend {
                Text(trend)
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(value). \(trend ?? "")")
    }
}

struct MetricCard_Previews: PreviewProvider {
    static var previews: some View {
        MetricCard(title: "Cost / km", value: "0.18 QAR", trend: "Better than last 5 fill-ups", icon: "creditcard", tint: .blue)
            .padding()
    }
}
