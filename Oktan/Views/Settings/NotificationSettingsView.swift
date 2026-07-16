import SwiftUI

struct NotificationSettingsView: View {
    @Bindable var notificationService: NotificationService
    @State private var showingPermissionAlert = false
    
    var body: some View {
        DetailShell(title: "Reminders") {
            // Authorization Section
            authorizationSection
            
            // Reminder Settings
            if notificationService.isAuthorized {
                reminderSection
                inactivitySection
            }
        }
        .onAppear {
            Task { await notificationService.checkAuthorizationStatus() }
        }
        .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                notificationService.openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable notifications in Settings to receive fill-up reminders.")
        }
    }
    
    // MARK: - Authorization Section
    
    private var authorizationSection: some View {
        Section {
            switch notificationService.authorizationStatus {
            case .authorized:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("Notifications Enabled")
                        .foregroundStyle(Color(uiColor: .label))
                }
                
            case .denied:
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.red)
                        Text("Notifications Disabled")
                            .foregroundStyle(Color(uiColor: .label))
                    }
                    
                    Button("Enable in Settings") {
                        notificationService.openSettings()
                    }
                    .font(.subheadline)
                }
                
            case .notDetermined:
                Button(action: requestPermission) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(Color.blue)
                        Text("Enable Notifications")
                        Spacer()
                        if notificationService.isPendingAuthorization {
                            ProgressView()
                        }
                    }
                }
                .disabled(notificationService.isPendingAuthorization)
                
            case .provisional, .ephemeral:
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(Color.orange)
                    Text("Limited Notifications")
                }
                
            @unknown default:
                Text("Unknown status")
            }
        } header: {
            Text("Permission")
        } footer: {
            if notificationService.authorizationStatus == .notDetermined {
                Text("Get reminders to log your fill-ups and track your fuel efficiency.")
            }
        }
    }
    
    // MARK: - Reminder Section
    
    private var reminderSection: some View {
        Section {
            Picker("Frequency", selection: $notificationService.reminderFrequency) {
                ForEach(NotificationService.ReminderFrequency.allCases) { frequency in
                    Text(frequency.displayName).tag(frequency)
                }
            }
            
            if notificationService.reminderFrequency == .weekly {
                Picker("Day", selection: $notificationService.reminderWeekDay) {
                    ForEach(NotificationService.WeekDay.allCases) { day in
                        Text(day.displayName).tag(day)
                    }
                }
            }
            
            if notificationService.reminderFrequency != .never {
                Picker("Time", selection: $notificationService.reminderHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
            }
        } header: {
            Text("Fill-up Reminders")
        } footer: {
            reminderFooterText
        }
    }
    
    @ViewBuilder
    private var reminderFooterText: some View {
        switch notificationService.reminderFrequency {
        case .never:
            Text("No reminders will be sent.")
        case .daily:
            Text("You'll receive a daily reminder at \(formatHour(notificationService.reminderHour)).")
        case .everyThreeDays:
            Text("You'll receive a reminder every 3 days.")
        case .weekly:
            Text("You'll receive a reminder every \(notificationService.reminderWeekDay.displayName) at \(formatHour(notificationService.reminderHour)).")
        case .biweekly:
            Text("You'll receive a reminder every 2 weeks.")
        case .monthly:
            Text("You'll receive a monthly reminder.")
        }
    }
    
    // MARK: - Inactivity Section
    
    private var inactivitySection: some View {
        Section {
            Toggle("Inactivity Reminder", isOn: $notificationService.inactivityReminderEnabled)

            if notificationService.inactivityReminderEnabled {
                Picker("Remind after", selection: $notificationService.inactivityDays) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("21 days").tag(21)
                    Text("30 days").tag(30)
                }
            }

            Toggle("Next Fill-up Prediction", isOn: $notificationService.nextFillupReminderEnabled)
        } header: {
            Text("Smart Reminders")
        } footer: {
            if notificationService.nextFillupReminderEnabled {
                Text("You'll be reminded on the day your next fill-up is predicted to be due, based on your average interval.")
            } else if notificationService.inactivityReminderEnabled {
                Text("You'll receive a reminder if you haven't logged a fill-up in \(notificationService.inactivityDays) days.")
            } else {
                Text("Get a gentle nudge when you haven't logged entries in a while.")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func requestPermission() {
        Task {
            let granted = await notificationService.requestAuthorization()
            if !granted {
                showingPermissionAlert = true
            }
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView(notificationService: NotificationService())
    }
}
