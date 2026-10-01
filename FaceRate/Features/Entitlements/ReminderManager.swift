import Foundation
import UserNotifications

/// Local weekly "time for your scan" reminder. Local notifications need no
/// Info.plist entry and never leave the device.
enum ReminderManager {
    static let id = "facerate.weekly_scan_reminder"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedules (or reschedules) a repeating weekly reminder — Sunday 10am.
    static func scheduleWeekly() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Time for your weekly scan", comment: "notification title")
        content.body = NSLocalizedString("See how your features are trending — it takes just a few seconds.", comment: "notification body")
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
