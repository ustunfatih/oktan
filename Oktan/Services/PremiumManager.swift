import SwiftUI
import RevenueCat
import OSLog

@MainActor
@Observable
class PremiumManager {
    private let logger = Logger(subsystem: "com.oktan.app", category: "Purchases")
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
            logger.warning("RevenueCat API key missing; premium features disabled")
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
                self?.logger.error("Customer info refresh failed: \(error.localizedDescription, privacy: .public)")
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

    /// Links App Store purchases to the private Sign in with Apple identifier.
    /// Signing out returns RevenueCat to an anonymous identity on this device.
    func synchronizeIdentity(userID: String?) async {
        guard isConfigured else { return }

        do {
            if let userID {
                guard Purchases.shared.appUserID != userID else { return }
                let result = try await Purchases.shared.logIn(userID)
                updatePremiumStatus(result.customerInfo)
            } else if !Purchases.shared.isAnonymous {
                let info = try await Purchases.shared.logOut()
                updatePremiumStatus(info)
            }
        } catch {
            logger.error("Purchase identity synchronization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Restores purchases (called manually if needed, though stream usually handles it)
    func restore() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.restorePurchases()
            updatePremiumStatus(info)
        } catch {
            logger.error("Purchase restore failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
