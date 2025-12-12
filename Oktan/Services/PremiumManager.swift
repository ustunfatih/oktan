import SwiftUI
import StoreKit

@Observable
final class PremiumManager {
    var isPremium: Bool {
        didSet {
            UserDefaults.standard.set(isPremium, forKey: "isPremiumUser")
        }
    }
    
    init() {
        self.isPremium = UserDefaults.standard.bool(forKey: "isPremiumUser")
    }
    
    /// Simulates a purchase
    func purchase() async throws {
        // Mock purchase delay
        try? await Task.sleep(for: .seconds(1))
        isPremium = true
    }
    
    func restore() async {
        // Mock restore
        try? await Task.sleep(for: .seconds(1))
        // In a real app, check receipt. For now, we assume restore just works if they acted premium before? 
        // Or simplified: it just sets premium for demo purposes if we want. 
        // But better to keep isPremium as is unless we have a logic.
        // For development, purchasing sets it.
    }
    
    #if DEBUG
    func reset() {
        isPremium = false
    }
    #endif
}
