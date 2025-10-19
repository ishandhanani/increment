import Foundation
import OSLog

/// Centralized logging for Increment app
/// Usage: AppLogger.session.info("Session started")
public enum AppLogger {
    /// Session lifecycle and state management
    public static let session = Logger(subsystem: subsystem, category: "session")

    /// Live Activity updates and lifecycle
    public static let liveActivity = Logger(subsystem: subsystem, category: "liveActivity")

    /// Notification permissions and management
    public static let notifications = Logger(subsystem: subsystem, category: "notifications")

    /// UI lifecycle and view events (debug only)
    public static let ui = Logger(subsystem: subsystem, category: "ui")

    /// General app-wide logger
    public static let general = Logger(subsystem: subsystem, category: "general")

    /// Database operations and persistence
    public static let database = Logger(subsystem: subsystem, category: "database")

    /// Persistence layer operations
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// Analytics data processing and caching
    public static let analytics = Logger(subsystem: subsystem, category: "analytics")

    private static let subsystem = "com.increment.app"
}
