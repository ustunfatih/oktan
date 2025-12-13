import Foundation
import UserNotifications
import UIKit

/// Service for managing local notifications and reminders
@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    
    // MARK: - Types
    
    /// Reminder frequency options
    enum ReminderFrequency: String, CaseIterable, Identifiable, Codable {
        case never = "Never"
        case daily = "Every day"
        case everyThreeDays = "Every 3 days"
        case weekly = "Weekly"
        case biweekly = "Every 2 weeks"
        case monthly = "Monthly"
        
        var id: String { rawValue }
        
        var days: Int? {
            switch self {
            case .never: return nil
            case .daily: return 1
            case .everyThreeDays: return 3
            case .weekly: return 7
            case .biweekly: return 14
            case .monthly: return 30
            }
        }
        
        var displayName: String { rawValue }
    }
    
    /// Day of week for weekly reminders
    enum WeekDay: Int, CaseIterable, Identifiable, Codable {
        case sunday = 1
        case monday = 2
        case tuesday = 3
        case wednesday = 4
        case thursday = 5
        case friday = 6
        case saturday = 7
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .sunday: return "Sunday"
            case .monday: return "Monday"
            case .tuesday: return "Tuesday"
            case .wednesday: return "Wednesday"
            case .thursday: return "Thursday"
            case .friday: return "Friday"
            case .saturday: return "Saturday"
            }
        }
    }
    
    /// Notification identifiers
    private enum NotificationID {
        static let fillupReminder = "oktan.reminder.fillup"
        static let inactivityReminder = "oktan.reminder.inactivity"
        static let smartRefuel = "smart_refuel_nudge"
    }
    
    // MARK: - Properties
    
    /// Signal to show add fuel screen (e.g. from notification tap)
    var shouldShowAddFuel = false
    
    /// Whether notifications are authorized
    private(set) var isAuthorized = false
    
    /// Current authorization status
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    /// Whether we're waiting for user permission response
    private(set) var isPendingAuthorization = false
    
    // MARK: - Settings (persisted)
    
    /// Reminder frequency
    var reminderFrequency: ReminderFrequency {
        didSet {
            UserDefaults.standard.set(reminderFrequency.rawValue, forKey: "reminderFrequency")
            Task { await scheduleReminders() }
        }
    }
    
    /// Preferred day for weekly reminders
    var reminderWeekDay: WeekDay {
        didSet {
            UserDefaults.standard.set(reminderWeekDay.rawValue, forKey: "reminderWeekDay")
            Task { await scheduleReminders() }
        }
    }
    
    /// Preferred hour for reminders (0-23)
    var reminderHour: Int {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: "reminderHour")
            Task { await scheduleReminders() }
        }
    }
    
    /// Whether inactivity reminders are enabled
    var inactivityReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(inactivityReminderEnabled, forKey: "inactivityReminderEnabled")
        }
    }
    
    /// Days of inactivity before reminder
    var inactivityDays: Int {
        didSet {
            UserDefaults.standard.set(inactivityDays, forKey: "inactivityDays")
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        // Load saved settings
        if let frequencyRaw = UserDefaults.standard.string(forKey: "reminderFrequency"),
           let frequency = ReminderFrequency(rawValue: frequencyRaw) {
            self.reminderFrequency = frequency
        } else {
            self.reminderFrequency = .never
        }
        
        let weekDayRaw = UserDefaults.standard.integer(forKey: "reminderWeekDay")
        self.reminderWeekDay = WeekDay(rawValue: weekDayRaw) ?? .monday
        
        let savedHour = UserDefaults.standard.integer(forKey: "reminderHour")
        self.reminderHour = savedHour > 0 ? savedHour : 9 // Default to 9 AM
        
        self.inactivityReminderEnabled = UserDefaults.standard.bool(forKey: "inactivityReminderEnabled")
        
        let savedInactivityDays = UserDefaults.standard.integer(forKey: "inactivityDays")
        self.inactivityDays = savedInactivityDays > 0 ? savedInactivityDays : 14
        
        super.init()
        
        // Set delegate
        UNUserNotificationCenter.current().delegate = self
        
        Task { await checkAuthorizationStatus() }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == NotificationID.smartRefuel {
            // Signal to show add fuel screen
            self.shouldShowAddFuel = true
        }
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    // MARK: - Authorization
    
    /// Checks current notification authorization status
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    /// Requests notification permissions
    func requestAuthorization() async -> Bool {
        isPendingAuthorization = true
        defer { isPendingAuthorization = false }
        
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            
            if granted {
                await scheduleReminders()
            }
            
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    /// Opens system settings for the app
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Scheduling
    
    /// Schedules all reminders based on current settings
    func scheduleReminders() async {
        // Cancel existing reminders first
        await cancelAllReminders()
        
        guard isAuthorized, reminderFrequency != .never else { return }
        
        await scheduleFillupReminder()
    }
    
    /// Schedules the fill-up reminder
    private func scheduleFillupReminder() async {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Time to Log Your Fill-up! ⛽"
        content.body = "Don't forget to record your fuel purchase in Oktan."
        content.sound = .default
        content.badge = 1
        
        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = 0
        
        // Configure trigger based on frequency
        let trigger: UNNotificationTrigger
        
        switch reminderFrequency {
        case .never:
            return
            
        case .daily:
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
        case .everyThreeDays, .biweekly, .monthly:
            // For intervals, use time interval trigger
            guard let days = reminderFrequency.days else { return }
            let interval = TimeInterval(days * 24 * 60 * 60)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
            
        case .weekly:
            dateComponents.weekday = reminderWeekDay.rawValue
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        }
        
        let request = UNNotificationRequest(
            identifier: NotificationID.fillupReminder,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            #if DEBUG
            print("📬 Scheduled fill-up reminder: \(reminderFrequency.displayName)")
            #endif
        } catch {
            print("Failed to schedule reminder: \(error)")
        }
    }
    
    /// Schedules an inactivity reminder
    func scheduleInactivityReminder(lastEntryDate: Date) async {
        guard isAuthorized, inactivityReminderEnabled else { return }
        
        let center = UNUserNotificationCenter.current()
        
        // Cancel existing inactivity reminder
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.inactivityReminder])
        
        // Calculate when to trigger
        let calendar = Calendar.current
        guard let triggerDate = calendar.date(byAdding: .day, value: inactivityDays, to: lastEntryDate) else { return }
        
        // Don't schedule if it's in the past
        guard triggerDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "We Miss You! 🚗"
        content.body = "It's been \(inactivityDays) days since your last fill-up log. Keeping records helps track your fuel efficiency."
        content.sound = .default
        
        var components = calendar.dateComponents([.year, .month, .day], from: triggerDate)
        components.hour = reminderHour
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: NotificationID.inactivityReminder,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            #if DEBUG
            print("📬 Scheduled inactivity reminder for \(triggerDate)")
            #endif
        } catch {
            print("Failed to schedule inactivity reminder: \(error)")
        }
    }
    
    /// Cancels all scheduled reminders
    func cancelAllReminders() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        // Also clear badge
        await MainActor.run {
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }
    
    /// Clears the app badge
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    // MARK: - Debugging
    
    #if DEBUG
    /// Lists all pending notifications (for debugging)
    func listPendingNotifications() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        
        print("📬 Pending notifications:")
        for request in requests {
            print("  - \(request.identifier): \(request.content.title)")
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                print("    Next: \(trigger.nextTriggerDate()?.description ?? "unknown")")
            }
        }
    }
    #endif
}

// MARK: - Notification Messages

extension NotificationService {
    /// Random motivational messages for variety
    static let fillupMessages = [
        "Time to Log Your Fill-up! ⛽",
        "Fuel Log Reminder 🚗",
        "Track Your Efficiency 📊",
        "Quick Fill-up Log? ⛽"
    ]
    
    static let fillupBodies = [
        "Don't forget to record your fuel purchase in Oktan.",
        "Log your fill-up to keep track of your fuel efficiency.",
        "A quick log helps you understand your driving costs.",
        "Your fuel tracking streak is waiting for you!"
    ]
}
