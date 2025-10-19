import Foundation
import SwiftData
import OSLog

/// Manages local persistence for sessions (SwiftData) and simple settings (UserDefaults)
@MainActor
class PersistenceManager {
    static let shared = PersistenceManager()

    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.increment", category: "PersistenceManager")

    // Keys for UserDefaults (simple settings only)
    private enum Keys {
        static let exerciseStates = "increment.exerciseStates"
    }

    enum PersistenceError: Error {
        case encodingFailed(String, Error)
        case decodingFailed(String, Error)
        case dataCorrupted(String)

        var localizedDescription: String {
            switch self {
            case .encodingFailed(let key, let error):
                return "Failed to encode data for key '\(key)': \(error.localizedDescription)"
            case .decodingFailed(let key, let error):
                return "Failed to decode data for key '\(key)': \(error.localizedDescription)"
            case .dataCorrupted(let key):
                return "Data corrupted for key '\(key)'"
            }
        }
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Sessions (SwiftData)

    func saveSession(_ session: Session, in context: ModelContext) {
        context.insert(session)
        do {
            try context.save()
            logger.debug("Successfully saved session to SwiftData")
        } catch {
            logger.error("Failed to save session: \(error.localizedDescription)")
        }
    }

    func loadSessions(from context: ModelContext) -> [Session] {
        let descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            let sessions = try context.fetch(descriptor)
            logger.debug("Successfully loaded \(sessions.count) sessions from SwiftData")
            return sessions
        } catch {
            logger.error("Failed to load sessions: \(error.localizedDescription)")
            return []
        }
    }

    func loadCurrentSession(from context: ModelContext) -> Session? {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        do {
            let sessions = try context.fetch(descriptor)
            if let currentSession = sessions.first {
                logger.debug("Successfully loaded current session from SwiftData")
                return currentSession
            } else {
                logger.debug("No active session found")
                return nil
            }
        } catch {
            logger.error("Failed to load current session: \(error.localizedDescription)")
            return nil
        }
    }

    func isSessionStale(_ session: Session, threshold: TimeInterval = 86400) -> Bool {
        // Consider a session stale if it's more than threshold seconds old (default: 24 hours)
        return Date().timeIntervalSince(session.lastUpdated) > threshold
    }

    func clearCurrentSession(in context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive == true }
        )
        do {
            let sessions = try context.fetch(descriptor)
            for session in sessions {
                session.isActive = false
            }
            try context.save()
            logger.debug("Cleared current session")
        } catch {
            logger.error("Failed to clear current session: \(error.localizedDescription)")
        }
    }

    // MARK: - Exercise States

    func saveExerciseStates(_ states: [String: ExerciseState]) {
        do {
            let data = try encoder.encode(states)
            userDefaults.set(data, forKey: Keys.exerciseStates)
            logger.debug("Successfully saved \(states.count) exercise states")
        } catch {
            let persistenceError = PersistenceError.encodingFailed(Keys.exerciseStates, error)
            logger.error("\(persistenceError.localizedDescription)")
        }
    }

    func loadExerciseStates() -> [String: ExerciseState] {
        guard let data = userDefaults.data(forKey: Keys.exerciseStates) else {
            logger.debug("No exercise states data found")
            return [:]
        }

        do {
            let states = try decoder.decode([String: ExerciseState].self, from: data)
            logger.debug("Successfully loaded \(states.count) exercise states")
            return states
        } catch {
            let persistenceError = PersistenceError.decodingFailed(Keys.exerciseStates, error)
            logger.error("\(persistenceError.localizedDescription)")
            return [:]
        }
    }

    // MARK: - Utilities

    func clearAll(context: ModelContext) {
        // Clear SwiftData
        do {
            try context.delete(model: Session.self)
            try context.save()
            logger.debug("Cleared all SwiftData")
        } catch {
            logger.error("Failed to clear SwiftData: \(error.localizedDescription)")
        }

        // Clear UserDefaults (keep migration flag)
        userDefaults.removeObject(forKey: Keys.exerciseStates)
        userDefaults.synchronize()
        logger.debug("Cleared UserDefaults settings")
    }
}