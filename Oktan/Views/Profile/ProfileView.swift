import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.large) {
                    if authManager.isAuthenticated, let user = authManager.currentUser {
                        authenticatedView(user: user)
                    } else {
                        unauthenticatedView
                    }
                }
                .padding(DesignSystem.Spacing.large)
            }
            .background(DesignSystem.ColorPalette.background.ignoresSafeArea())
            .navigationTitle("Profile")
        }
    }
    
    // MARK: - Authenticated View
    
    private func authenticatedView(user: AuthenticationManager.User) -> some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.ColorPalette.primaryBlue, DesignSystem.ColorPalette.deepPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Text(user.initials)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            .shadow(color: DesignSystem.ColorPalette.primaryBlue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // User Info
            VStack(spacing: DesignSystem.Spacing.small) {
                Text(user.displayName)
                    .font(.title2.bold())
                    .foregroundStyle(DesignSystem.ColorPalette.label)
                
                if let email = user.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                }
                
                HStack(spacing: DesignSystem.Spacing.xsmall) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DesignSystem.ColorPalette.successGreen)
                    Text("Signed in with Apple")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                }
                .padding(.top, DesignSystem.Spacing.xsmall)
            }
            
            // Benefits Section
            benefitsSection
            
            // Sign Out Button
            Button(action: { showingSignOutConfirmation = true }) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.medium)
            }
            .buttonStyle(.bordered)
            .tint(DesignSystem.ColorPalette.errorRed)
            .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    // MARK: - Unauthenticated View
    
    private var unauthenticatedView: some View {
        VStack(spacing: DesignSystem.Spacing.xlarge) {
            // Hero Illustration
            VStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.ColorPalette.primaryBlue, DesignSystem.ColorPalette.deepPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Sign in to Oktan")
                    .font(.title.bold())
                    .foregroundStyle(DesignSystem.ColorPalette.label)
                
                Text("Sync your data across devices and unlock premium features")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
            
            // Benefits
            benefitsSection
            
            // Sign in with Apple Button
            signInWithAppleButton
            
            // Error Message
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.ColorPalette.errorRed)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
            
            // Privacy Note
            Text("We only use your Apple ID to identify you. Your data stays private.")
                .font(.caption)
                .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Benefits Section
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            benefitRow(icon: "icloud.fill", title: "Cloud Sync", description: "Access your data on all devices")
            benefitRow(icon: "lock.shield.fill", title: "Secure Backup", description: "Never lose your fuel logs")
            benefitRow(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Detailed insights and trends")
        }
        .padding(DesignSystem.Spacing.large)
        .glassCard()
    }
    
    private func benefitRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DesignSystem.ColorPalette.primaryBlue)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.ColorPalette.label)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
            }
        }
    }
    
    // MARK: - Sign in with Apple Button
    
    private var signInWithAppleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            // Handled by AuthenticationManager
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous))
        .overlay {
            // Custom tap handler using our AuthenticationManager
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    authManager.signInWithApple()
                }
        }
        .disabled(authManager.isLoading)
        .opacity(authManager.isLoading ? 0.6 : 1.0)
        .overlay {
            if authManager.isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthenticationManager())
}
