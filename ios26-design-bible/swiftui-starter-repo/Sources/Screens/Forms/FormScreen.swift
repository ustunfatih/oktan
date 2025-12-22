import SwiftUI

struct FormScreen: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false

    var body: some View {
        FormShell(title: "Form") {
            Section("Account") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            Section {
                Button("Sign In") {
                    showError = email.isEmpty || password.isEmpty
                }
                .buttonStyle(.borderedProminent)

                if showError {
                    Text("Please fill in both email and password.")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Error: Please fill in both email and password.")
                }
            }
        }
    }
}
