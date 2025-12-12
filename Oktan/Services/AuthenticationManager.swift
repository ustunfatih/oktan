import AuthenticationServices
import SwiftUI

/// Manages Sign in with Apple authentication
@Observable
final class AuthenticationManager: NSObject {
    
    // MARK: - User State
    
    struct User: Codable, Equatable {
        let id: String
        let email: String?
        let fullName: String?
        let givenName: String?
        let familyName: String?
        
        var displayName: String {
            if let fullName, !fullName.isEmpty {
                return fullName
            }
            if let givenName {
                return givenName
            }
            if let email {
                return email
            }
            return "User"
        }
        
        var initials: String {
            let names = displayName.split(separator: " ")
            if names.count >= 2 {
                return "\(names[0].prefix(1))\(names[1].prefix(1))"
            }
            return String(displayName.prefix(2)).uppercased()
        }
    }
    
    // MARK: - Properties
    
    private(set) var currentUser: User?
    private(set) var isAuthenticated: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    
    private let userDefaultsKey = "authenticatedUser"
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        loadStoredUser()
    }
    
    // MARK: - Public Methods
    
    /// Initiates Sign in with Apple flow
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
    
    /// Signs out the current user
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Checks if the Apple ID credential is still valid
    func checkCredentialState() {
        guard let userId = currentUser?.id else { return }
        
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userId) { [weak self] state, error in
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    // Credential is valid
                    break
                case .revoked, .notFound:
                    // Credential was revoked or not found, sign out
                    self?.signOut()
                case .transferred:
                    // Account was transferred to a different team
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadStoredUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return
        }
        
        currentUser = user
        isAuthenticated = true
        
        // Verify credential is still valid
        checkCredentialState()
    }
    
    private func saveUser(_ user: User) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        isLoading = false
        
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Invalid credential type"
            return
        }
        
        // Extract user info
        let userId = credential.user
        let email = credential.email
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        // Create or update user
        // Note: Apple only provides name/email on first sign-in
        // After that, we need to use stored values
        let user: User
        if let existingUser = currentUser, existingUser.id == userId {
            // Update with new info if provided, otherwise keep existing
            user = User(
                id: userId,
                email: email ?? existingUser.email,
                fullName: fullName.isEmpty ? existingUser.fullName : fullName,
                givenName: credential.fullName?.givenName ?? existingUser.givenName,
                familyName: credential.fullName?.familyName ?? existingUser.familyName
            )
        } else {
            user = User(
                id: userId,
                email: email,
                fullName: fullName.isEmpty ? nil : fullName,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName
            )
        }
        
        currentUser = user
        isAuthenticated = true
        saveUser(user)
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                // User canceled, don't show error
                break
            case .failed:
                errorMessage = String(localized: "Sign in failed. Please try again.")
            case .invalidResponse:
                errorMessage = String(localized: "Invalid response from Apple.")
            case .notHandled:
                errorMessage = String(localized: "Sign in request was not handled.")
            case .unknown:
                errorMessage = String(localized: "An unknown error occurred.")
            case .notInteractive:
                errorMessage = String(localized: "Sign in requires user interaction.")
            @unknown default:
                errorMessage = error.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }
    }
}
