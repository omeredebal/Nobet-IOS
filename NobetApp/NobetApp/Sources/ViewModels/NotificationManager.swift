import Foundation
import UserNotifications

// MARK: - NotificationManager

@MainActor
final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Schedule

    /// Schedule a local notification for a patient timer.
    func schedule(timer: PatientTimer, patientBed: String) {
        cancel(notificationID: timer.notificationID)
        let content         = UNMutableNotificationContent()
        content.title       = "Yatak \(patientBed) · \(timer.text)"
        content.body        = "Hatırlatıcı zamanı geldi."
        content.sound       = .defaultCritical
        content.categoryIdentifier = "TIMER"

        let interval = timer.due.timeIntervalSinceNow
        guard interval > 0 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: timer.notificationID,
                                            content: content,
                                            trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    /// Cancel a specific timer notification.
    func cancel(notificationID: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    /// Cancel all pending notifications.
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Snooze: remove existing and re-schedule.
    func snooze(timer: PatientTimer, patientBed: String) {
        cancel(notificationID: timer.notificationID)
        let interval = timer.due.timeIntervalSinceNow
        guard interval > 0 else { return }
        let content         = UNMutableNotificationContent()
        content.title       = "Yatak \(patientBed) · \(timer.text)"
        content.body        = "Ertelendi – yeniden hatırlatma."
        content.sound       = .defaultCritical
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: timer.notificationID,
                                            content: content,
                                            trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
