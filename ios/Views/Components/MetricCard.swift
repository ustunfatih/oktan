import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let trend: String?
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)

            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            if let trend {
                Text(trend)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(value). \(trend ?? "")")
    }
}

#Preview {
    MetricCard(title: "Cost / km", value: "0.18 QAR", trend: "Better than last 5 fill-ups", icon: "creditcard", tint: .blue)
        .padding()
}
