import SwiftUI
import RevenueCat

@MainActor
@Observable
class PremiumManager {
    var isPremium = false
    
    init() {
        // Initialize RevenueCat
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_HcxhrgEARdQuoUxajGLEasDwAGm")

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
                await updatePremiumStatus(customerInfo)
            }
        }
    }
    
    func updatePremiumStatus(_ info: CustomerInfo) {
        // Prefer a specific entitlement, but fall back to any active entitlement or subscription.
        let namedEntitlementIsActive = info.entitlements["Oktan Pro"]?.isActive == true
        let anyEntitlementIsActive = !info.entitlements.active.isEmpty
        let hasActiveSubscription = !info.activeSubscriptions.isEmpty
        let hasAnyPurchase = !info.allPurchasedProductIdentifiers.isEmpty
        self.isPremium = namedEntitlementIsActive || anyEntitlementIsActive || hasActiveSubscription || hasAnyPurchase
    }
    
    /// Restores purchases (called manually if needed, though stream usually handles it)
    func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            await updatePremiumStatus(info)
        } catch {
            print("Restore failed: \(error)")
        }
    }
}
