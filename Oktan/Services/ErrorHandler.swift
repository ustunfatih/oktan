import SwiftUI

/// Centralized error handling and presentation
@MainActor
@Observable
final class ErrorHandler {
    
    // MARK: - Properties
    
    /// Current error to display (nil if no error)
    private(set) var currentError: OktanError?
    
    /// Whether an error alert is being shown
    var isShowingError: Bool {
        get { currentError != nil }
        set { if !newValue { currentError = nil } }
    }
    
    /// Retry action for recoverable errors
    private var retryAction: (() async -> Void)?
    
    /// Number of retry attempts for current operation
    private var retryCount: Int = 0
    
    /// Maximum retry attempts
    private let maxRetries: Int = 3
    
    // MARK: - Error Handling
    
    /// Handles an error, optionally with a retry action
    func handle(_ error: Error, retryAction: (() async -> Void)? = nil) {
        let oktanError = OktanError.from(error)
        
        // Don't show cancelled errors
        if case .cancelled = oktanError { return }
        
        self.currentError = oktanError
        self.retryAction = retryAction
        self.retryCount = 0
        
        // Log error for debugging
        #if DEBUG
        print("🔴 Error: \(oktanError.errorDescription ?? "Unknown")")
        if let suggestion = oktanError.recoverySuggestion {
            print("   Suggestion: \(suggestion)")
        }
        #endif
        
        // Haptic feedback for errors
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// Handles an OktanError directly
    func handle(_ error: OktanError, retryAction: (() async -> Void)? = nil) {
        if case .cancelled = error { return }
        
        self.currentError = error
        self.retryAction = retryAction
        self.retryCount = 0
        
        #if DEBUG
        print("🔴 Error: \(error.errorDescription ?? "Unknown")")
        #endif
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// Dismisses the current error
    func dismiss() {
        currentError = nil
        retryAction = nil
        retryCount = 0
    }
    
    /// Retries the failed operation
    func retry() async {
        guard let action = retryAction, retryCount < maxRetries else {
            dismiss()
            return
        }
        
        retryCount += 1
        dismiss()
        
        // Small delay before retry
        try? await Task.sleep(for: .milliseconds(500))
        
        await action()
    }
    
    /// Whether retry is available for current error
    var canRetry: Bool {
        currentError?.isRecoverable == true && 
        retryAction != nil && 
        retryCount < maxRetries
    }
    
    // MARK: - Convenience Methods
    
    /// Executes an async operation with automatic error handling
    func withErrorHandling<T>(
        retryable: Bool = false,
        operation: @escaping () async throws -> T
    ) async -> T? {
        do {
            return try await operation()
        } catch {
            if retryable {
                handle(error) { [weak self] in
                    _ = await self?.withErrorHandling(retryable: true, operation: operation)
                }
            } else {
                handle(error)
            }
            return nil
        }
    }
    
    /// Executes a throwing operation with automatic error handling
    func withErrorHandling<T>(
        operation: () throws -> T
    ) -> T? {
        do {
            return try operation()
        } catch {
            handle(error)
            return nil
        }
    }
}

// MARK: - Error Alert Modifier

/// View modifier for displaying error alerts
struct ErrorAlertModifier: ViewModifier {
    @Bindable var errorHandler: ErrorHandler
    
    func body(content: Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorHandler.isShowingError },
                    set: { if !$0 { errorHandler.dismiss() } }
                ),
                presenting: errorHandler.currentError
            ) { error in
                if errorHandler.canRetry {
                    Button("Retry") {
                        Task { await errorHandler.retry() }
                    }
                    Button("Cancel", role: .cancel) {
                        errorHandler.dismiss()
                    }
                } else {
                    Button("OK", role: .cancel) {
                        errorHandler.dismiss()
                    }
                }
            } message: { error in
                VStack {
                    Text(error.errorDescription ?? "An unexpected error occurred")
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
    }
}

extension View {
    /// Adds error alert handling to a view
    func errorAlert(_ errorHandler: ErrorHandler) -> some View {
        modifier(ErrorAlertModifier(errorHandler: errorHandler))
    }
}

// MARK: - Error Banner View

/// A banner-style error view for inline display
struct ErrorBannerView: View {
    let error: OktanError
    let onDismiss: () -> Void
    var onRetry: (() async -> Void)?
    
    @State private var isRetrying = false
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: error.systemIcon)
                .font(.title2)
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "An error occurred")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            if error.isRecoverable, let retry = onRetry {
                Button {
                    isRetrying = true
                    Task {
                        await retry()
                        isRetrying = false
                    }
                } label: {
                    if isRetrying {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Retry")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(isRetrying)
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                .fill(Color.red.gradient)
        )
        .padding(.horizontal, DesignSystem.Spacing.medium)
    }
}

// MARK: - Empty State Error View

/// A full-screen error state view
struct ErrorStateView: View {
    let error: OktanError
    var onRetry: (() async -> Void)?
    
    @State private var isRetrying = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Image(systemName: error.systemIcon)
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red.opacity(0.8), .orange.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Something went wrong")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DesignSystem.ColorPalette.label)
                
                Text(error.errorDescription ?? "An unexpected error occurred")
                    .font(.body)
                    .foregroundStyle(DesignSystem.ColorPalette.secondaryLabel)
                    .multilineTextAlignment(.center)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.ColorPalette.tertiaryLabel)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xlarge)
            
            if error.isRecoverable, let retry = onRetry {
                Button {
                    isRetrying = true
                    Task {
                        await retry()
                        isRetrying = false
                    }
                } label: {
                    HStack {
                        if isRetrying {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Try Again")
                    }
                    .font(.headline)
                    .frame(minWidth: 120)
                    .padding(.vertical, DesignSystem.Spacing.medium)
                    .padding(.horizontal, DesignSystem.Spacing.xlarge)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.ColorPalette.primaryBlue)
                .disabled(isRetrying)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.ColorPalette.background)
    }
}

// MARK: - Preview

#Preview("Error Banner") {
    VStack {
        Spacer()
        ErrorBannerView(
            error: .noConnection,
            onDismiss: {},
            onRetry: { try? await Task.sleep(for: .seconds(1)) }
        )
    }
    .background(DesignSystem.ColorPalette.background)
}

#Preview("Error State") {
    ErrorStateView(
        error: .loadFailed(reason: "Could not connect to database"),
        onRetry: { try? await Task.sleep(for: .seconds(1)) }
    )
}
