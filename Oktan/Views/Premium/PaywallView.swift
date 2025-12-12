import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        // RevenueCat's drop-in Paywall UI
        // It automatically fetches the 'Current' Offering configured in the Dashboard.
        // Make sure your Offering contains packages with identifiers matching your configured products.
        RevenueCatUI.PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { customerInfo in
                print("Purchase completed: \(customerInfo.entitlements)")
                dismiss()
            }
            .onRestoreCompleted { customerInfo in
                print("Restore completed: \(customerInfo)")
                dismiss()
            }
    }
}
