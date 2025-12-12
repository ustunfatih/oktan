import SwiftUI

struct PaywallView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background
            DesignSystem.ColorPalette.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.large) {
                // Header
                VStack(spacing: DesignSystem.Spacing.medium) {
                    Image("StartIcon") // Placeholder or GasPump
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundStyle(DesignSystem.ColorPalette.primaryBlue)
                    
                    Text("Unlock Oktan Premium")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(DesignSystem.ColorPalette.label)
                        .multilineTextAlignment(.center)
                    
                    Text("Get advanced insights and keep your data safe.")
                        .font(.body)
                        .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignSystem.Spacing.xlarge)
                
                // Features
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                    FeatureRow(icon: "chart.xyaxis.line", title: "Advanced Analytics", description: "Trends, patterns, and efficieny insights.")
                    FeatureRow(icon: "icloud", title: "Cloud Sync", description: "Sync data across all your devices.")
                    FeatureRow(icon: "doc.text", title: "Unlimited Export", description: "Export your data to CSV and PDF.")
                    FeatureRow(icon: "app.badge", title: "Custom App Icons", description: "Personalize your home screen.")
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: DesignSystem.Spacing.medium) {
                    if isPurchasing {
                        ProgressView()
                            .tint(DesignSystem.ColorPalette.primaryBlue)
                    } else {
                        Button(action: purchase) {
                            Text("Subscribe for $4.99/year")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(DesignSystem.ColorPalette.primaryBlue)
                                .foregroundColor(.white)
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        
                        Button("Restore Purchases", action: restore)
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.ColorPalette.errorRed)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.large)
                .padding(.bottom, DesignSystem.Spacing.large)
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
    
    private func purchase() {
        isPurchasing = true
        Task {
            do {
                try await premiumManager.purchase()
                isPurchasing = false
                dismiss()
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func restore() {
        isPurchasing = true
        Task {
            await premiumManager.restore()
            isPurchasing = false
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DesignSystem.ColorPalette.primaryBlue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.ColorPalette.label)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            }
        }
    }
}

#Preview {
    PaywallView()
        .environment(PremiumManager())
}
