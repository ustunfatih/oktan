import SwiftUI
import SwiftData

// MARK: - Feature Flags

/// Controls whether to use SwiftData or legacy JSON storage
/// Set to true to enable SwiftData globally
private let useSwiftData = true

@main
struct OktanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - SwiftData Container
    
    /// SwiftData model container (always created for migration support)
    private let modelContainer: ModelContainer
    
    // MARK: - Repositories
    
    /// The main fuel repository - uses SwiftData or JSON based on feature flag
    @StateObject private var repository: FuelRepository
    
    /// Car repository with SwiftData support
    @State private var carRepository: CarRepositorySD?
    
    /// Legacy car repository for fallback
    @State private var legacyCarRepository = CarRepository()
    
    // MARK: - Services
    
    /// Global error handler
    @State private var errorHandler = ErrorHandler()
    
    /// Notification service
    @State private var notificationService = NotificationService()
    
    // MARK: - Other State
    
    @State private var appSettings = AppSettings()
    @State private var authManager = AuthenticationManager()
    @State private var premiumManager = PremiumManager()
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var isInitialized = false

    // MARK: - Initialization
    
    init() {
        // Initialize SwiftData container
        do {
            let container = try DataContainer.create()
            self.modelContainer = container
            
            if useSwiftData {
                // Create FuelRepository with SwiftData backend
                let context = container.mainContext
                _repository = StateObject(wrappedValue: FuelRepository(modelContext: context))
            } else {
                // Create FuelRepository with JSON backend
                _repository = StateObject(wrappedValue: FuelRepository())
            }
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if let carRepoSD = carRepository {
                        RootScaffold()
                            .environment(carRepoSD)
                    } else {
                        RootScaffold()
                            .environment(legacyCarRepository)
                    }
                }
                    .environmentObject(repository)
                    .environment(appSettings)
                    .environment(authManager)
                    .environment(errorHandler)
                    .environment(notificationService)
                    .environment(premiumManager)
                    .errorAlert(errorHandler)
                    .opacity(showSplash ? 0 : 1)
                    .modelContainer(modelContainer)
                    .preferredColorScheme(appSettings.theme.colorScheme)
                
                if showSplash {
                    SplashView()
                }
            }
            .task {
                // Initialize
                await initialize()
                
                // Check credential state on app launch
                authManager.checkCredentialState()
                
                // Dismiss splash after startup tasks complete
                try? await Task.sleep(for: .seconds(5.0))
                showSplash = false
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    notificationService.clearBadge()
                }
            }
        }
    }
    
    // MARK: - Initialization
    
    @MainActor
    private func initialize() async {
        guard !isInitialized else { return }
        
        let context = modelContainer.mainContext
        
        // Perform migration from JSON if needed
        if useSwiftData {
            let migrationResult = await DataMigrationService.migrateIfNeeded(context: context)
            if !migrationResult.alreadyCompleted {
                print("Migration: \(migrationResult.description)")
            }
            
            // Initialize SwiftData car repository
            carRepository = CarRepositorySD(modelContext: context)
        }
        
        // Bootstrap with seed data if empty
        repository.bootstrapIfNeeded()
        
        isInitialized = true
    }
}

// MARK: - Main Tab View (DEPRECATED - Use RootScaffold instead)
// This is kept for reference but RootScaffold is now the primary tab container.
// RootScaffold provides:
// - @SceneStorage for tab persistence (Bible Article VI compliance)
// - No .tint() override (Bible Article III compliance)
// - Navigation path persistence for each tab
