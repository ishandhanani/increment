import Foundation
import OSLog

/// Manages local persistence for sessions, exercise states, and profiles using SQLite
@MainActor
class PersistenceManager {
    static let shared = PersistenceManager()

    private let db = DatabaseManager.shared
    private let logger = AppLogger.persistence

    enum PersistenceError: Error {
        case databaseError(Error)

        var localizedDescription: String {
            switch self {
            case .databaseError(let error):
                return "Database error: \(error.localizedDescription)"
            }
        }
    }

    private init() {}

    // MARK: - Sessions

    func saveSessions(_ sessions: [Session]) async {
        do {
            try await db.saveSessions(sessions)
            logger.debug("Successfully saved \(sessions.count) sessions")
        } catch {
            logger.error("Failed to save sessions: \(error.localizedDescription)")
        }
    }

    func loadSessions() async -> [Session] {
        do {
            let sessions = try await db.loadSessions()
            logger.debug("Successfully loaded \(sessions.count) sessions")
            return sessions
        } catch {
            logger.error("Failed to load sessions: \(error.localizedDescription)")
            return []
        }
    }

    func saveCurrentSession(_ session: Session?) async {
        do {
            try await db.saveCurrentSession(session)
            logger.debug("Successfully saved current session")
        } catch {
            logger.error("Failed to save current session: \(error.localizedDescription)")
        }
    }

    func loadCurrentSession() async -> Session? {
        do {
            let session = try await db.loadCurrentSession()
            logger.debug("Successfully loaded current session")
            return session
        } catch {
            logger.error("Failed to load current session: \(error.localizedDescription)")
            return nil
        }
    }

    func isSessionStale(_ session: Session, threshold: TimeInterval = 86400) -> Bool {
        // Consider a session stale if it's more than threshold seconds old (default: 24 hours)
        return Date().timeIntervalSince(session.lastUpdated) > threshold
    }

    func clearCurrentSession() async {
        do {
            try await db.clearCurrentSession()
            logger.debug("Cleared current session")
        } catch {
            logger.error("Failed to clear current session: \(error.localizedDescription)")
        }
    }

    func clearCurrentSessionSync() {
        do {
            try db.clearCurrentSessionSync()
            logger.debug("Cleared current session (sync)")
        } catch {
            logger.error("Failed to clear current session (sync): \(error.localizedDescription)")
        }
    }

    // MARK: - Exercise States

    func saveExerciseStates(_ states: [String: ExerciseState]) async {
        do {
            try await db.saveExerciseStates(states)
            logger.debug("Successfully saved \(states.count) exercise states")
        } catch {
            logger.error("Failed to save exercise states: \(error.localizedDescription)")
        }
    }

    func loadExerciseStates() async -> [String: ExerciseState] {
        do {
            let states = try await db.loadExerciseStates()
            logger.debug("Successfully loaded \(states.count) exercise states")
            return states
        } catch {
            logger.error("Failed to load exercise states: \(error.localizedDescription)")
            return [:]
        }
    }

    // MARK: - Synchronous Methods (for critical saves)

    func saveCurrentSessionSync(_ session: Session?) {
        do {
            try db.saveCurrentSessionSync(session)
            logger.debug("Successfully saved current session (sync)")
        } catch {
            logger.error("Failed to save current session (sync): \(error.localizedDescription)")
        }
    }

    func saveSessionsSync(_ sessions: [Session]) {
        do {
            try db.saveSessionsSync(sessions)
            logger.debug("Successfully saved \(sessions.count) sessions (sync)")
        } catch {
            logger.error("Failed to save sessions (sync): \(error.localizedDescription)")
        }
    }

    func loadSessionsSync() -> [Session] {
        do {
            let sessions = try db.loadSessionsSync()
            logger.debug("Successfully loaded \(sessions.count) sessions (sync)")
            return sessions
        } catch {
            logger.error("Failed to load sessions (sync): \(error.localizedDescription)")
            return []
        }
    }

    func loadCurrentSessionSync() -> Session? {
        do {
            let session = try db.loadCurrentSessionSync()
            logger.debug("Successfully loaded current session (sync)")
            return session
        } catch {
            logger.error("Failed to load current session (sync): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Utilities

    func clearAll() async {
        do {
            try await db.clearAll()
            logger.notice("Cleared all data")
        } catch {
            logger.error("Failed to clear all data: \(error.localizedDescription)")
        }
    }
}