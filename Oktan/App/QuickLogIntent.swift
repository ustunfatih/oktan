import AppIntents
import Foundation

enum QuickLogRequest {
    private static let key = "quickLog.intentRequested"

    static func signal() {
        UserDefaults(suiteName: "group.com.oktan.data")?.set(true, forKey: key)
    }

    static func consume() -> Bool {
        let defaults = UserDefaults(suiteName: "group.com.oktan.data")
        guard defaults?.bool(forKey: key) == true else { return false }
        defaults?.removeObject(forKey: key)
        return true
    }
}

struct QuickLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Log"
    static var description = IntentDescription("Open Oktan directly to a new fill-up form.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickLogRequest.signal()
        return .result()
    }
}

struct OktanAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLogIntent(),
            phrases: [
                "Log fuel in \(.applicationName)",
                "Add a fill-up in \(.applicationName)",
                "Quick log with \(.applicationName)"
            ],
            shortTitle: "Quick Log",
            systemImageName: "fuelpump.fill"
        )
    }
}
