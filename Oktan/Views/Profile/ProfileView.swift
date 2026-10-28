import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.onAccent) private var onAccent
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        ListShell(title: "Profile") {
            if authManager.isAuthenticated, let user = authManager.currentUser {
                authenticatedSections(user: user)
            } else {
                unauthenticatedSections
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Authenticated Sections
    // Removed: LinearGradient, fixed frame dimensions

    @ViewBuilder
    private func authenticatedSections(user: AuthenticationManager.User) -> some View {
        // Profile Header Section
        Section {
            HStack {
                Text(user.initials)
                    .font(.headline)
                    .foregroundStyle(onAccent)
                    .padding()
                    .background(Circle().fill(.tint))

                VStack(alignment: .leading) {
                    Text(user.displayName)
                        .font(.headline)

                    if let email = user.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Label("Signed in with Apple", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        
        // Benefits Section
        Section {
            benefitRow(icon: "lock.iphone", title: "Private Profile", description: "Your profile is stored securely on this device")
            benefitRow(icon: "arrow.clockwise.icloud", title: "Purchase Restore", description: "Restore Oktan Pro through the App Store")
            benefitRow(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Detailed insights and trends")
        } header: {
            Text("Account Benefits")
        }
        
        // Sign Out Section
        Section {
            Button(role: .destructive, action: { showingSignOutConfirmation = true }) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
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
    
    // MARK: - Unauthenticated Sections
    // Removed: fixed font size .system(size: 60)

    @ViewBuilder
    private var unauthenticatedSections: some View {
        // Welcome Section
        Section {
            VStack {
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)

                Text("Sign in to Oktan")
                    .font(.title2.bold())

                Text("Keep a private profile and connect your Oktan Pro purchase")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .listRowBackground(Color.clear)
        
        // Benefits Section
        Section {
            benefitRow(icon: "lock.iphone", title: "Private Profile", description: "Your profile is stored securely on this device")
            benefitRow(icon: "arrow.clockwise.icloud", title: "Purchase Restore", description: "Restore Oktan Pro through the App Store")
            benefitRow(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Detailed insights and trends")
        } header: {
            Text("Benefits")
        }
        
        // Sign In Section
        Section {
            Button(action: { authManager.signInWithApple() }) {
                Label("Sign in with Apple", systemImage: "apple.logo")
                    .frame(maxWidth: .infinity)
            }
            .accentProminentButton()
            .disabled(authManager.isLoading)
            
            if authManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            
            // Error Message
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .listRowBackground(Color.clear)
        
        // Privacy Note
        Section {
            Text("We only use your Apple ID to identify you. Your data stays private.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Benefit Row
    
    private func benefitRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        Label {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.tint)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthenticationManager())
}
