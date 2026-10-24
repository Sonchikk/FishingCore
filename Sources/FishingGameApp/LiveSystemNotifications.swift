import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Abstraction over system local notifications (`UNUserNotificationCenter`) used by `FishingBiteNotificationScheduler`
/// (`CHECKMODE` / `AlarmManagerBroadcastReceiver` at `BEGINTIME`).
public protocol SystemNotificationScheduling: Sendable {
    func requestAuthorization()
    func scheduleLocal(id: String, title: String, body: String, delaySeconds: TimeInterval)
    func removePending(id: String)
    func removeAllPending()
}

/// Production notification scheduler backed by `UNUserNotificationCenter`.
/// This is the sole file in `Sources/` referencing `UNUserNotificationCenter`.
public struct LiveSystemNotifications: SystemNotificationScheduling, Sendable {
    public init() {}

    public func requestAuthorization() {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        #endif
    }

    public func scheduleLocal(
        id: String,
        title: String,
        body: String,
        delaySeconds: TimeInterval
    ) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1.0, delaySeconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
        center.add(request, withCompletionHandler: nil)
        #endif
    }

    public func removePending(id: String) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
        #endif
    }

    public func removeAllPending() {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        #endif
    }
}

/// No-op notification scheduler used in unit tests (`swift test` / `xctest`) where no `.app` bundle proxy exists.
public struct NoopSystemNotifications: SystemNotificationScheduling, Sendable {
    public init() {}

    public func requestAuthorization() {}

    public func scheduleLocal(
        id: String,
        title: String,
        body: String,
        delaySeconds: TimeInterval
    ) {}

    public func removePending(id: String) {}

    public func removeAllPending() {}
}
