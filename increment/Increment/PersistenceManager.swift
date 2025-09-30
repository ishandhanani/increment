import Foundation

/// Manages local persistence for sessions, exercise states, and profiles
class PersistenceManager {
    static let shared = PersistenceManager()

    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Keys
    private enum Keys {
        static let sessions = "increment.sessions"
        static let exerciseStates = "increment.exerciseStates"
        static let exerciseProfiles = "increment.exerciseProfiles"
        static let workoutPlans = "increment.workoutPlans"
        static let currentSession = "increment.currentSession"
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Sessions

    func saveSessions(_ sessions: [Session]) {
        if let data = try? encoder.encode(sessions) {
            userDefaults.set(data, forKey: Keys.sessions)
        }
    }

    func loadSessions() -> [Session] {
        guard let data = userDefaults.data(forKey: Keys.sessions),
              let sessions = try? decoder.decode([Session].self, from: data) else {
            return []
        }
        return sessions
    }

    func saveCurrentSession(_ session: Session?) {
        if let session = session,
           let data = try? encoder.encode(session) {
            userDefaults.set(data, forKey: Keys.currentSession)
        } else {
            userDefaults.removeObject(forKey: Keys.currentSession)
        }
    }

    func loadCurrentSession() -> Session? {
        guard let data = userDefaults.data(forKey: Keys.currentSession),
              let session = try? decoder.decode(Session.self, from: data) else {
            return nil
        }
        return session
    }

    // MARK: - Exercise States

    func saveExerciseStates(_ states: [UUID: ExerciseState]) {
        if let data = try? encoder.encode(states) {
            userDefaults.set(data, forKey: Keys.exerciseStates)
        }
    }

    func loadExerciseStates() -> [UUID: ExerciseState] {
        guard let data = userDefaults.data(forKey: Keys.exerciseStates),
              let states = try? decoder.decode([UUID: ExerciseState].self, from: data) else {
            return [:]
        }
        return states
    }

    // MARK: - Exercise Profiles

    func saveExerciseProfiles(_ profiles: [UUID: ExerciseProfile]) {
        if let data = try? encoder.encode(profiles) {
            userDefaults.set(data, forKey: Keys.exerciseProfiles)
        }
    }

    func loadExerciseProfiles() -> [UUID: ExerciseProfile] {
        guard let data = userDefaults.data(forKey: Keys.exerciseProfiles),
              let profiles = try? decoder.decode([UUID: ExerciseProfile].self, from: data) else {
            return [:]
        }
        return profiles
    }

    // MARK: - Workout Plans

    func saveWorkoutPlans(_ plans: [WorkoutPlan]) {
        if let data = try? encoder.encode(plans) {
            userDefaults.set(data, forKey: Keys.workoutPlans)
        }
    }

    func loadWorkoutPlans() -> [WorkoutPlan] {
        guard let data = userDefaults.data(forKey: Keys.workoutPlans),
              let plans = try? decoder.decode([WorkoutPlan].self, from: data) else {
            return []
        }
        return plans
    }

    // MARK: - Utilities

    func clearAll() {
        userDefaults.removeObject(forKey: Keys.sessions)
        userDefaults.removeObject(forKey: Keys.exerciseStates)
        userDefaults.removeObject(forKey: Keys.exerciseProfiles)
        userDefaults.removeObject(forKey: Keys.workoutPlans)
        userDefaults.removeObject(forKey: Keys.currentSession)
    }

    func exportData() -> [String: Any] {
        return [
            "sessions": loadSessions().map { try? encoder.encode($0) }.compactMap { $0 },
            "exerciseStates": loadExerciseStates(),
            "exerciseProfiles": loadExerciseProfiles(),
            "workoutPlans": loadWorkoutPlans()
        ]
    }
}