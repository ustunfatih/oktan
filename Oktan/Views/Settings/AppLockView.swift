import SwiftUI

struct AppLockView: View {
    @Environment(AppLockManager.self) private var appLockManager

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)

                Text("Oktan is Locked")
                    .font(.title.bold())

                Text("Authenticate to view your fuel records.")
                    .foregroundStyle(.secondary)

                Button {
                    Task { await appLockManager.unlock() }
                } label: {
                    if appLockManager.isAuthenticating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Unlock with \(appLockManager.biometricName)", systemImage: "faceid")
                            .frame(maxWidth: .infinity)
                    }
                }
                .accentProminentButton()
                .disabled(appLockManager.isAuthenticating)

                if let error = appLockManager.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .task { await appLockManager.unlock() }
        .accessibilityAddTraits(.isModal)
    }
}

struct AppLockSettingsView: View {
    @Environment(AppLockManager.self) private var appLockManager

    var body: some View {
        DetailShell(title: "App Lock") {
            Section {
                Toggle("Require Authentication", isOn: Binding(
                    get: { appLockManager.isEnabled },
                    set: { enabled in
                        Task { await appLockManager.setEnabled(enabled) }
                    }
                ))
                .disabled(appLockManager.isAuthenticating)
            } footer: {
                Text("Locks Oktan after it moves to the background and uses your device passcode, Face ID, Touch ID, or Optic ID.")
            }

            if let error = appLockManager.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
