import Foundation
import LocalAuthentication

@MainActor
@Observable
final class AppLockManager {
    private static let enabledKey = "appLockEnabled"

    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    private(set) var errorMessage: String?

    init() {
        let enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        isLocked = enabled
    }

    var biometricName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "device authentication"
        }
    }

    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }
        guard await authenticate(reason: enabled
            ? String(localized: "Protect your fuel records")
            : String(localized: "Turn off Oktan app lock")) else { return }

        isEnabled = enabled
        isLocked = false
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
    }

    func lockIfNeeded() {
        guard isEnabled, !isAuthenticating else { return }
        isLocked = true
    }

    func unlock() async {
        guard isEnabled, isLocked else { return }
        if await authenticate(reason: String(localized: "Unlock Oktan")) {
            isLocked = false
        }
    }

    @discardableResult
    private func authenticate(reason: String) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            errorMessage = String(localized: "Set up a device passcode or biometric authentication first.")
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            if (error as? LAError)?.code != .userCancel {
                errorMessage = String(localized: "Authentication failed. Please try again.")
            }
            return false
        }
    }
}
