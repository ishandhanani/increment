@preconcurrency import UserNotifications
import Foundation
import OSLog

/// Manages notification permissions for Live Activities
@MainActor
public class NotificationManager {
    public static let shared = NotificationManager()

    private init() {}

    /// Request notification permissions (required for Live Activities)
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            if granted {
                AppLogger.notifications.notice("Notification permission granted")
            } else {
                AppLogger.notifications.info("Notification permission denied by user")
            }
            return granted
        } catch {
            AppLogger.notifications.error("Failed to request notification permission: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Check current notification authorization status
    public func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Check if notifications are authorized
    public func isAuthorized() async -> Bool {
        let status = await checkAuthorizationStatus()
        return status == .authorized
    }
}
