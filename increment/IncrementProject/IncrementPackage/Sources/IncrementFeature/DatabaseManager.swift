import Foundation
import GRDB
import OSLog

/// Manages SQLite database using GRDB
///
/// Thread Safety:
/// - DatabaseManager uses GRDB's DatabaseQueue which is thread-safe
/// - All database operations are serialized through the queue
/// - Reads and writes are properly isolated
/// - The @unchecked Sendable conformance is safe because:
///   1. dbQueue (DatabaseQueue) is internally thread-safe
///   2. logger is an immutable value (OSLog)
///   3. All mutable state is contained within the thread-safe dbQueue
class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()

    private let dbQueue: DatabaseQueue
    private let logger = AppLogger.database

    private init() {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            logger.error("Failed to get application support directory")
            fatalError("Database initialization failed: Cannot access application support directory")
        }

        let dbPath = appSupport.appendingPathComponent("increment.sqlite").path
        logger.info("Database path: \(dbPath, privacy: .public)")

        do {
            dbQueue = try DatabaseQueue(path: dbPath)
            logger.debug("Database queue created")

            // Run migrations
            try migrator.migrate(dbQueue)
            logger.notice("Database initialized successfully")
        } catch {
            logger.error("Failed to initialize database: \(error.localizedDescription)")
            logger.error("Error details: \(String(describing: error), privacy: .public)")
            fatalError("Database initialization failed: \(error)")
        }
    }

    // MARK: - Schema

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("schema") { db in
            // Sessions table
            try db.create(table: "sessions") { t in
                t.primaryKey("id", .text)
                t.column("date", .double).notNull()
                t.column("preWorkoutFeeling", .blob)
                t.column("stats", .blob)
                t.column("synced", .boolean).notNull().defaults(to: false)
                t.column("workoutTemplate", .blob)
                t.column("isActive", .boolean).notNull().defaults(to: true)
                t.column("currentExerciseIndex", .integer)
                t.column("currentSetIndex", .integer)
                t.column("sessionStateRaw", .text)
                t.column("currentExerciseLog", .blob)
                t.column("lastUpdated", .double).notNull()
            }

            // Exercise logs table
            try db.create(table: "exercise_logs") { t in
                t.primaryKey("id", .text)
                t.column("sessionId", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("exerciseId", .text).notNull()
                t.column("startWeight", .double).notNull()
                t.column("sessionDecision", .text)
                t.column("nextStartWeight", .double)
                t.column("orderIndex", .integer).notNull()
            }

            // Set logs table
            try db.create(table: "set_logs") { t in
                t.primaryKey("id", .text)
                t.column("exerciseLogId", .text).notNull()
                    .references("exercise_logs", onDelete: .cascade)
                t.column("setIndex", .integer).notNull()
                t.column("targetReps", .integer).notNull()
                t.column("targetWeight", .double).notNull()
                t.column("achievedReps", .integer).notNull()
                t.column("rating", .text).notNull()
                t.column("actualWeight", .double).notNull()
                t.column("restPlannedSec", .integer)
            }

            // Exercise states table
            try db.create(table: "exercise_states") { t in
                t.primaryKey("exerciseId", .text)
                t.column("lastStartLoad", .double).notNull()
                t.column("lastDecision", .text)
                t.column("lastUpdatedAt", .double).notNull()
            }

            // Custom lifts table
            try db.create(table: "custom_lifts") { t in
                t.primaryKey("id", .text)
                t.column("lift", .blob).notNull()
                t.column("createdAt", .double).notNull()
            }

            // Custom workout templates table
            try db.create(table: "custom_templates") { t in
                t.primaryKey("id", .text)
                t.column("template", .blob).notNull()
                t.column("createdAt", .double).notNull()
            }

            // Workout rotation table (stores ordered list of template IDs)
            try db.create(table: "workout_rotation") { t in
                t.primaryKey("id", .text)
                t.column("templateIds", .blob).notNull() // JSON array of UUIDs
                t.column("updatedAt", .double).notNull()
            }

            // Indexes for performance
            try db.create(index: "idx_sessions_date", on: "sessions", columns: ["date"])
            try db.create(index: "idx_sessions_active", on: "sessions", columns: ["isActive"])
            try db.create(index: "idx_exercise_logs_session", on: "exercise_logs", columns: ["sessionId", "orderIndex"])
            try db.create(index: "idx_set_logs_exercise", on: "set_logs", columns: ["exerciseLogId", "setIndex"])
            try db.create(index: "idx_exercise_states_updated", on: "exercise_states", columns: ["lastUpdatedAt"])
            try db.create(index: "idx_custom_lifts_created", on: "custom_lifts", columns: ["createdAt"])
            try db.create(index: "idx_custom_templates_created", on: "custom_templates", columns: ["createdAt"])
        }

        return migrator
    }

    // MARK: - Sessions

    func saveSessions(_ sessions: [Session]) async throws {
        try await dbQueue.write { db in
            for session in sessions {
                try self.saveSessionRecord(session, to: db)
            }
        }
        logger.debug("Saved \(sessions.count) sessions")
    }

    func loadSessions() async throws -> [Session] {
        try await dbQueue.read { db in
            let records = try SessionRecord
                .order(Column("date").desc)
                .fetchAll(db)

            return try records.map { try self.loadFullSession(from: $0, db: db) }
        }
    }

    func saveCurrentSession(_ session: Session?) async throws {
        try await dbQueue.write { db in
            // Clear all active sessions
            try db.execute(sql: "UPDATE sessions SET isActive = 0 WHERE isActive = 1")

            // Save new active session
            if let session = session {
                var mutableSession = session
                mutableSession.isActive = true
                try self.saveSessionRecord(mutableSession, to: db)
            }
        }
        logger.debug("Saved current session")
    }

    /// Synchronous version for critical saves (blocking)
    func saveCurrentSessionSync(_ session: Session?) throws {
        try dbQueue.write { db in
            // Clear all active sessions
            try db.execute(sql: "UPDATE sessions SET isActive = 0 WHERE isActive = 1")

            // Save new active session
            if let session = session {
                var mutableSession = session
                mutableSession.isActive = true
                try self.saveSessionRecord(mutableSession, to: db)
            }
        }
        logger.debug("Saved current session (sync)")
    }

    /// Synchronous version for saving to history
    func saveSessionsSync(_ sessions: [Session]) throws {
        try dbQueue.write { db in
            for session in sessions {
                try self.saveSessionRecord(session, to: db)
            }
        }
        logger.debug("Saved \(sessions.count) sessions (sync)")
    }

    /// Synchronous load for blocking reads
    func loadSessionsSync() throws -> [Session] {
        try dbQueue.read { db in
            let records = try SessionRecord
                .order(Column("date").desc)
                .fetchAll(db)

            return try records.map { try self.loadFullSession(from: $0, db: db) }
        }
    }

    /// Synchronous load current session
    func loadCurrentSessionSync() throws -> Session? {
        try dbQueue.read { db in
            guard let record = try SessionRecord
                .filter(Column("isActive") == true)
                .fetchOne(db) else {
                return nil
            }

            return try self.loadFullSession(from: record, db: db)
        }
    }

    func loadCurrentSession() async throws -> Session? {
        try await dbQueue.read { db in
            guard let record = try SessionRecord
                .filter(Column("isActive") == true)
                .fetchOne(db) else {
                return nil
            }

            return try self.loadFullSession(from: record, db: db)
        }
    }

    func clearCurrentSession() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "UPDATE sessions SET isActive = 0 WHERE isActive = 1")
        }
        logger.debug("Cleared current session")
    }

    func clearCurrentSessionSync() throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE sessions SET isActive = 0 WHERE isActive = 1")
        }
        logger.debug("Cleared current session (sync)")
    }

    // MARK: - Exercise States

    func saveExerciseStates(_ states: [String: ExerciseState]) async throws {
        try await dbQueue.write { db in
            for (_, state) in states {
                let record = ExerciseStateRecord(from: state)
                try record.save(db)
            }
        }
        logger.debug("Saved \(states.count) exercise states")
    }

    func loadExerciseStates() async throws -> [String: ExerciseState] {
        try await dbQueue.read { db in
            let records = try ExerciseStateRecord.fetchAll(db)
            return Dictionary(
                uniqueKeysWithValues: records.map { ($0.exerciseId, $0.toModel()) }
            )
        }
    }

    // MARK: - Custom Lifts

    func saveCustomLift(_ lift: Lift) async throws {
        try await dbQueue.write { db in
            let record = CustomLiftRecord(id: UUID(), lift: lift, createdAt: Date())
            try record.save(db)
        }
        logger.debug("Saved custom lift: \(lift.name)")
    }

    func loadCustomLifts() async throws -> [Lift] {
        try await dbQueue.read { db in
            let records = try CustomLiftRecord
                .order(Column("createdAt").desc)
                .fetchAll(db)
            return records.compactMap { $0.toModel()?.lift }
        }
    }

    func deleteCustomLift(named name: String) async throws {
        try await dbQueue.write { db in
            // Find and delete the record with matching lift name
            let records = try CustomLiftRecord.fetchAll(db)
            for record in records {
                if let model = record.toModel(), model.lift.name == name {
                    try db.execute(sql: "DELETE FROM custom_lifts WHERE id = ?", arguments: [record.id])
                    logger.debug("Deleted custom lift: \(name)")
                    return
                }
            }
        }
    }

    // MARK: - Custom Workout Templates

    func saveCustomTemplate(_ template: WorkoutTemplate) async throws {
        try await dbQueue.write { db in
            let record = CustomTemplateRecord(id: template.id, template: template, createdAt: Date())
            try record.save(db)
        }
        logger.debug("Saved custom template: \(template.name)")
    }

    func loadCustomTemplates() async throws -> [WorkoutTemplate] {
        try await dbQueue.read { db in
            let records = try CustomTemplateRecord
                .order(Column("createdAt").desc)
                .fetchAll(db)
            return records.compactMap { $0.toModel()?.template }
        }
    }

    func deleteCustomTemplate(id: UUID) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM custom_templates WHERE id = ?", arguments: [id.uuidString])
        }
        logger.debug("Deleted custom template: \(id)")
    }

    // MARK: - Workout Rotation

    func saveWorkoutRotation(_ templateIds: [UUID]) async throws {
        try await dbQueue.write { db in
            let record = WorkoutRotationRecord(templateIds: templateIds, updatedAt: Date())
            try record.save(db)
        }
        logger.debug("Saved workout rotation with \(templateIds.count) templates")
    }

    func loadWorkoutRotation() async throws -> [UUID]? {
        try await dbQueue.read { db in
            guard let record = try WorkoutRotationRecord
                .order(Column("updatedAt").desc)
                .fetchOne(db) else {
                return nil
            }
            return record.toModel()?.templateIds
        }
    }

    // MARK: - Utilities

    func clearAll() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM sessions")
            try db.execute(sql: "DELETE FROM exercise_states")
        }
        logger.notice("Cleared all data")
    }

    // MARK: - Helper Methods

    private func saveSessionRecord(_ session: Session, to db: Database) throws {
        let sessionRecord = SessionRecord(from: session)
        try sessionRecord.save(db)

        // Delete existing exercise logs for this session (for updates)
        try db.execute(sql: "DELETE FROM exercise_logs WHERE sessionId = ?", arguments: [session.id.uuidString])

        // Save exercise logs
        for (index, exerciseLog) in session.exerciseLogs.enumerated() {
            let logRecord = ExerciseLogRecord(
                from: exerciseLog,
                sessionId: session.id.uuidString,
                orderIndex: index
            )
            try logRecord.save(db)

            // Save set logs
            for setLog in exerciseLog.setLogs {
                let setRecord = SetLogRecord(
                    from: setLog,
                    exerciseLogId: exerciseLog.id.uuidString
                )
                try setRecord.save(db)
            }
        }
    }

    private func loadFullSession(from record: SessionRecord, db: Database) throws -> Session {
        // Load exercise logs for this session
        let exerciseLogRecords = try ExerciseLogRecord
            .filter(Column("sessionId") == record.id)
            .order(Column("orderIndex"))
            .fetchAll(db)

        let exerciseLogs = try exerciseLogRecords.map { logRecord -> ExerciseSessionLog in
            // Load set logs for this exercise
            let setLogRecords = try SetLogRecord
                .filter(Column("exerciseLogId") == logRecord.id)
                .order(Column("setIndex"))
                .fetchAll(db)

            let setLogs = setLogRecords.map { $0.toModel() }
            return logRecord.toModel(setLogs: setLogs)
        }

        return record.toModel(exerciseLogs: exerciseLogs)
    }
}
