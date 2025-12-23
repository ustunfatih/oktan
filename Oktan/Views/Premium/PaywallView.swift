import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PremiumManager.self) private var premiumManager

    var body: some View {
        // RevenueCat's drop-in Paywall UI
        // It automatically fetches the 'Current' Offering configured in the Dashboard.
        // Make sure your Offering contains packages with identifiers matching your configured products.
        RevenueCatUI.PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { customerInfo in
                print("Purchase completed: \(customerInfo.entitlements)")
                Task { @MainActor in
                    premiumManager.updatePremiumStatus(customerInfo)
                }
                Purchases.shared.getCustomerInfo { info, error in
                    if let info {
                        Task { @MainActor in
                            premiumManager.updatePremiumStatus(info)
                        }
                    } else if let error {
                        print("Failed to refresh customer info: \(error)")
                    }
                }
                dismiss()
            }
            .onRestoreCompleted { customerInfo in
                print("Restore completed: \(customerInfo)")
                Task { @MainActor in
                    premiumManager.updatePremiumStatus(customerInfo)
                }
                Purchases.shared.getCustomerInfo { info, error in
                    if let info {
                        Task { @MainActor in
                            premiumManager.updatePremiumStatus(info)
                        }
                    } else if let error {
                        print("Failed to refresh customer info: \(error)")
                    }
                }
                dismiss()
            }
    }
}
