import SwiftUI
import RevenueCat

@MainActor
@Observable
class PremiumManager {
    var isPremium = false

    /// The RevenueCat entitlement that unlocks Oktan Pro features.
    static let proEntitlementID = "Oktan Pro"

    /// Whether the RevenueCat SDK was configured with a valid API key.
    private(set) var isConfigured = false

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        // The API key is injected via Config/Secrets.xcconfig -> Info.plist.
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              !apiKey.isEmpty, !apiKey.hasPrefix("$(") else {
            print("PremiumManager: RevenueCatAPIKey missing from Info.plist; premium features disabled.")
            return
        }

        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true

        // Seed initial state in case the stream doesn't emit immediately.
        Purchases.shared.getCustomerInfo { [weak self] info, error in
            if let info {
                Task { @MainActor in
                    self?.updatePremiumStatus(info)
                }
            } else if let error {
                print("Failed to fetch customer info: \(error)")
            }
        }

        // Listen for subscription status changes
        Task {
            for await customerInfo in Purchases.shared.customerInfoStream {
                updatePremiumStatus(customerInfo)
            }
        }
    }

    func updatePremiumStatus(_ info: CustomerInfo) {
        isPremium = info.entitlements[Self.proEntitlementID]?.isActive == true
    }

    /// Restores purchases (called manually if needed, though stream usually handles it)
    func restore() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.restorePurchases()
            updatePremiumStatus(info)
        } catch {
            print("Restore failed: \(error)")
        }
    }
}
