import UserNotifications
import Foundation

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
            print(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error.localizedDescription)")
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
