import Foundation
import SwiftData
import UserNotifications

enum ReminderScheduler {
    static let reminderID = "quarterly-snapshot-reminder"
    static let prefKey = "reminderEnabled"
    static let intervalKey = "reminderIntervalDays"

    /// User-configurable cadence (Settings → Reminders). Defaults to 90 days.
    static var intervalDays: Int {
        let v = UserDefaults.standard.integer(forKey: intervalKey)
        return v > 0 ? v : 90
    }

    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: prefKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: prefKey)
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func check(context: ModelContext) {
        guard isEnabled else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
            return
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async { schedule(context: context) }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async { schedule(context: context) }
            default:
                // Denied — nothing to schedule. Settings surfaces the state
                // with a deep link to System Settings.
                break
            }
        }
    }

    static func applyPreference(enabled: Bool, context: ModelContext) {
        if enabled {
            check(context: context)
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
        }
    }

    private static func schedule(context: ModelContext) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let latest = (try? context.fetch(descriptor))?.first
        let lastDate = latest?.date ?? .distantPast
        let nextDue = Calendar.current.date(byAdding: .day, value: intervalDays, to: lastDate) ?? .now
        let interval = max(nextDue.timeIntervalSinceNow, 60)

        let content = UNMutableNotificationContent()
        content.title = "Time for a Snapshot"
        content.body = latest == nil
            ? "Create your first snapshot in Quiet Finance."
            : "Last snapshot was \(intervalDays)+ days ago. Log current balances."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
    }
}
