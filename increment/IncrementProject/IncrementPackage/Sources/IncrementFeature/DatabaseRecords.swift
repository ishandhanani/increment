import Foundation
import GRDB

// MARK: - SessionRecord

struct SessionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "sessions"

    var id: String
    var date: Double
    var preWorkoutFeeling: Data?
    var stats: Data?
    var synced: Bool
    var workoutTemplate: Data?
    var isActive: Bool
    var currentExerciseIndex: Int?
    var currentSetIndex: Int?
    var sessionStateRaw: String?
    var currentExerciseLog: Data?
    var lastUpdated: Double

    init(from session: Session) {
        self.id = session.id.uuidString
        self.date = session.date.timeIntervalSince1970
        self.synced = session.synced
        self.isActive = session.isActive
        self.currentExerciseIndex = session.currentExerciseIndex
        self.currentSetIndex = session.currentSetIndex
        self.sessionStateRaw = session.sessionStateRaw
        self.lastUpdated = session.lastUpdated.timeIntervalSince1970

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        self.preWorkoutFeeling = try? encoder.encode(session.preWorkoutFeeling)
        self.stats = try? encoder.encode(session.stats)
        self.workoutTemplate = try? encoder.encode(session.workoutTemplate)
        self.currentExerciseLog = try? encoder.encode(session.currentExerciseLog)
    }

    func toModel(exerciseLogs: [ExerciseSessionLog]) -> Session {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return Session(
            id: UUID(uuidString: id) ?? UUID(),
            date: Date(timeIntervalSince1970: date),
            preWorkoutFeeling: preWorkoutFeeling.flatMap { try? decoder.decode(PreWorkoutFeeling.self, from: $0) },
            exerciseLogs: exerciseLogs,
            stats: stats.flatMap { try? decoder.decode(SessionStats.self, from: $0) } ?? SessionStats(totalVolume: 0),
            synced: synced,
            workoutTemplate: workoutTemplate.flatMap { try? decoder.decode(WorkoutTemplate.self, from: $0) },
            isActive: isActive,
            currentExerciseIndex: currentExerciseIndex,
            currentSetIndex: currentSetIndex,
            sessionStateRaw: sessionStateRaw,
            currentExerciseLog: currentExerciseLog.flatMap { try? decoder.decode(ExerciseSessionLog.self, from: $0) },
            lastUpdated: Date(timeIntervalSince1970: lastUpdated)
        )
    }
}

// MARK: - ExerciseLogRecord

struct ExerciseLogRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "exercise_logs"

    var id: String
    var sessionId: String
    var exerciseId: String
    var startWeight: Double
    var sessionDecision: String?
    var nextStartWeight: Double?
    var orderIndex: Int

    init(from log: ExerciseSessionLog, sessionId: String, orderIndex: Int) {
        self.id = log.id.uuidString
        self.sessionId = sessionId
        self.exerciseId = log.exerciseId
        self.startWeight = log.startWeight
        self.sessionDecision = log.sessionDecision?.rawValue
        self.nextStartWeight = log.nextStartWeight
        self.orderIndex = orderIndex
    }

    func toModel(setLogs: [SetLog]) -> ExerciseSessionLog {
        ExerciseSessionLog(
            id: UUID(uuidString: id) ?? UUID(),
            exerciseId: exerciseId,
            startWeight: startWeight,
            setLogs: setLogs,
            sessionDecision: sessionDecision.flatMap { SessionDecision(rawValue: $0) },
            nextStartWeight: nextStartWeight
        )
    }
}

// MARK: - SetLogRecord

struct SetLogRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "set_logs"

    var id: String
    var exerciseLogId: String
    var setIndex: Int
    var targetReps: Int
    var targetWeight: Double
    var achievedReps: Int
    var rating: String
    var actualWeight: Double
    var restPlannedSec: Int?

    init(from setLog: SetLog, exerciseLogId: String) {
        self.id = setLog.id.uuidString
        self.exerciseLogId = exerciseLogId
        self.setIndex = setLog.setIndex
        self.targetReps = setLog.targetReps
        self.targetWeight = setLog.targetWeight
        self.achievedReps = setLog.achievedReps
        self.rating = setLog.rating.rawValue
        self.actualWeight = setLog.actualWeight
        self.restPlannedSec = setLog.restPlannedSec
    }

    func toModel() -> SetLog {
        SetLog(
            id: UUID(uuidString: id) ?? UUID(),
            setIndex: setIndex,
            targetReps: targetReps,
            targetWeight: targetWeight,
            achievedReps: achievedReps,
            rating: Rating(rawValue: rating) ?? .easy,
            actualWeight: actualWeight,
            restPlannedSec: restPlannedSec
        )
    }
}

// MARK: - ExerciseStateRecord

struct ExerciseStateRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "exercise_states"

    var exerciseId: String
    var lastStartLoad: Double
    var lastDecision: String?
    var lastUpdatedAt: Double

    init(from state: ExerciseState) {
        self.exerciseId = state.exerciseId
        self.lastStartLoad = state.lastStartLoad
        self.lastDecision = state.lastDecision?.rawValue
        self.lastUpdatedAt = state.lastUpdatedAt.timeIntervalSince1970
    }

    func toModel() -> ExerciseState {
        ExerciseState(
            exerciseId: exerciseId,
            lastStartLoad: lastStartLoad,
            lastDecision: lastDecision.flatMap { SessionDecision(rawValue: $0) },
            lastUpdatedAt: Date(timeIntervalSince1970: lastUpdatedAt)
        )
    }
}
