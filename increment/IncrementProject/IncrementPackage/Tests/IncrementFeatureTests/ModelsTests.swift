import Testing
import Foundation
@testable import IncrementFeature

/// Tests for data models
/// Validates Codable conformance, initialization, and data integrity
@Suite("Models Tests")
struct ModelsTests {

    // MARK: - ExerciseProfile Tests

    /// Test ExerciseProfile initialization with all parameters
    @Test("ExerciseProfile: Initializes with all parameters")
    func testExerciseProfileInit() {
        // Arrange & Act
        let profile = ExerciseProfile(
            name: "Test Exercise",
            category: .barbell,
            priority: .upper,
            repRange: 5...8,
            sets: 3,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0,
            plateOptions: [45, 25, 10, 5, 2.5],
            warmupRule: "ramped_2",
            defaultRestSec: 90
        )

        // Assert
        #expect(profile.name == "Test Exercise")
        #expect(profile.category == .barbell)
        #expect(profile.priority == .upper)
        #expect(profile.repRange == 5...8)
        #expect(profile.sets == 3)
        #expect(profile.baseIncrement == 5.0)
        #expect(profile.rounding == 2.5)
        #expect(profile.microAdjustStep == 2.5)
        #expect(profile.weeklyCapPct == 5.0)
        #expect(profile.plateOptions == [45, 25, 10, 5, 2.5])
        #expect(profile.warmupRule == "ramped_2")
        #expect(profile.defaultRestSec == 90)
    }

    /// Test ExerciseProfile Codable encoding and decoding
    @Test("ExerciseProfile: Encodes and decodes correctly")
    func testExerciseProfileCodable() throws {
        // Arrange
        let profile = ExerciseProfile(
            name: "Bench Press",
            category: .barbell,
            priority: .upper,
            repRange: 5...8,
            sets: 3,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0,
            plateOptions: [45, 25, 10],
            warmupRule: "ramped_2",
            defaultRestSec: 90
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(profile)
        let decoded = try decoder.decode(ExerciseProfile.self, from: data)

        // Assert
        #expect(decoded.id == profile.id)
        #expect(decoded.name == profile.name)
        #expect(decoded.category == profile.category)
        #expect(decoded.priority == profile.priority)
        #expect(decoded.repRange == profile.repRange)
        #expect(decoded.sets == profile.sets)
        #expect(decoded.baseIncrement == profile.baseIncrement)
        #expect(decoded.rounding == profile.rounding)
        #expect(decoded.microAdjustStep == profile.microAdjustStep)
        #expect(decoded.weeklyCapPct == profile.weeklyCapPct)
        #expect(decoded.plateOptions == profile.plateOptions)
        #expect(decoded.warmupRule == profile.warmupRule)
        #expect(decoded.defaultRestSec == profile.defaultRestSec)
    }

    // MARK: - ClosedRange Codable Tests

    /// Test ClosedRange<Int> encoding and decoding
    @Test("ClosedRange: Encodes and decodes Int range correctly")
    func testClosedRangeIntCodable() throws {
        // Arrange
        let range = 5...8
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(range)
        let decoded = try decoder.decode(ClosedRange<Int>.self, from: data)

        // Assert
        #expect(decoded.lowerBound == 5)
        #expect(decoded.upperBound == 8)
        #expect(decoded == range)
    }

    // MARK: - Rating Enum Tests

    /// Test Rating enum cases and raw values
    @Test("Rating: Has correct cases and raw values")
    func testRatingEnum() {
        // Assert
        #expect(Rating.fail.rawValue == "FAIL")
        #expect(Rating.holyShit.rawValue == "HOLY_SHIT")
        #expect(Rating.hard.rawValue == "HARD")
        #expect(Rating.easy.rawValue == "EASY")
        #expect(Rating.allCases.count == 4)
    }

    /// Test Rating Codable conformance
    @Test("Rating: Encodes and decodes correctly")
    func testRatingCodable() throws {
        // Arrange
        let ratings: [Rating] = [.fail, .holyShit, .hard, .easy]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act & Assert
        for rating in ratings {
            let data = try encoder.encode(rating)
            let decoded = try decoder.decode(Rating.self, from: data)
            #expect(decoded == rating)
        }
    }

    // MARK: - SessionDecision Enum Tests

    /// Test SessionDecision enum cases
    @Test("SessionDecision: Has correct cases and raw values")
    func testSessionDecisionEnum() {
        // Assert
        #expect(SessionDecision.up_2.rawValue == "up_2")
        #expect(SessionDecision.up_1.rawValue == "up_1")
        #expect(SessionDecision.hold.rawValue == "hold")
        #expect(SessionDecision.down_1.rawValue == "down_1")
    }

    // MARK: - SetLog Tests

    /// Test SetLog initialization
    @Test("SetLog: Initializes correctly")
    func testSetLogInit() {
        // Arrange & Act
        let setLog = SetLog(
            setIndex: 1,
            targetReps: 8,
            targetWeight: 100.0,
            achievedReps: 7,
            rating: .hard,
            actualWeight: 100.0,
            restPlannedSec: 90
        )

        // Assert
        #expect(setLog.setIndex == 1)
        #expect(setLog.targetReps == 8)
        #expect(setLog.targetWeight == 100.0)
        #expect(setLog.achievedReps == 7)
        #expect(setLog.rating == .hard)
        #expect(setLog.actualWeight == 100.0)
        #expect(setLog.restPlannedSec == 90)
    }

    /// Test SetLog Codable conformance
    @Test("SetLog: Encodes and decodes correctly")
    func testSetLogCodable() throws {
        // Arrange
        let setLog = SetLog(
            setIndex: 2,
            targetReps: 8,
            targetWeight: 95.0,
            achievedReps: 8,
            rating: .easy,
            actualWeight: 95.0,
            restPlannedSec: 120
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(setLog)
        let decoded = try decoder.decode(SetLog.self, from: data)

        // Assert
        #expect(decoded.id == setLog.id)
        #expect(decoded.setIndex == setLog.setIndex)
        #expect(decoded.targetReps == setLog.targetReps)
        #expect(decoded.targetWeight == setLog.targetWeight)
        #expect(decoded.achievedReps == setLog.achievedReps)
        #expect(decoded.rating == setLog.rating)
        #expect(decoded.actualWeight == setLog.actualWeight)
        #expect(decoded.restPlannedSec == setLog.restPlannedSec)
    }

    // MARK: - ExerciseSessionLog Tests

    /// Test ExerciseSessionLog initialization
    @Test("ExerciseSessionLog: Initializes with default values")
    func testExerciseSessionLogInit() {
        // Arrange
        let exerciseId = UUID()

        // Act
        let sessionLog = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: 100.0
        )

        // Assert
        #expect(sessionLog.exerciseId == exerciseId)
        #expect(sessionLog.startWeight == 100.0)
        #expect(sessionLog.setLogs.isEmpty)
        #expect(sessionLog.sessionDecision == nil)
        #expect(sessionLog.nextStartWeight == nil)
    }

    /// Test ExerciseSessionLog Codable conformance
    @Test("ExerciseSessionLog: Encodes and decodes correctly")
    func testExerciseSessionLogCodable() throws {
        // Arrange
        let exerciseId = UUID()
        let setLog = SetLog(
            setIndex: 1,
            targetReps: 8,
            targetWeight: 100.0,
            achievedReps: 8,
            rating: .easy,
            actualWeight: 100.0
        )

        let sessionLog = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: 100.0,
            setLogs: [setLog],
            sessionDecision: .up_1,
            nextStartWeight: 105.0
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(sessionLog)
        let decoded = try decoder.decode(ExerciseSessionLog.self, from: data)

        // Assert
        #expect(decoded.id == sessionLog.id)
        #expect(decoded.exerciseId == sessionLog.exerciseId)
        #expect(decoded.startWeight == sessionLog.startWeight)
        #expect(decoded.setLogs.count == 1)
        #expect(decoded.sessionDecision == .up_1)
        #expect(decoded.nextStartWeight == 105.0)
    }

    // MARK: - PreWorkoutFeeling Tests

    /// Test PreWorkoutFeeling initialization
    @Test("PreWorkoutFeeling: Initializes correctly")
    func testPreWorkoutFeelingInit() {
        // Arrange & Act
        let feeling = PreWorkoutFeeling(rating: 4, note: "Feeling strong")

        // Assert
        #expect(feeling.rating == 4)
        #expect(feeling.note == "Feeling strong")
    }

    /// Test PreWorkoutFeeling with nil note
    @Test("PreWorkoutFeeling: Handles nil note")
    func testPreWorkoutFeelingNilNote() {
        // Arrange & Act
        let feeling = PreWorkoutFeeling(rating: 3)

        // Assert
        #expect(feeling.rating == 3)
        #expect(feeling.note == nil)
    }

    /// Test PreWorkoutFeeling Codable conformance
    @Test("PreWorkoutFeeling: Encodes and decodes correctly")
    func testPreWorkoutFeelingCodable() throws {
        // Arrange
        let feeling = PreWorkoutFeeling(rating: 5, note: "Perfect")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(feeling)
        let decoded = try decoder.decode(PreWorkoutFeeling.self, from: data)

        // Assert
        #expect(decoded.rating == feeling.rating)
        #expect(decoded.note == feeling.note)
    }

    // MARK: - Session Tests

    /// Test Session initialization with defaults
    @Test("Session: Initializes with default values")
    func testSessionInit() {
        // Arrange
        let workoutPlanId = UUID()

        // Act
        let session = Session(workoutPlanId: workoutPlanId)

        // Assert
        #expect(session.workoutPlanId == workoutPlanId)
        #expect(session.preWorkoutFeeling == nil)
        #expect(session.exerciseLogs.isEmpty)
        #expect(session.stats.totalVolume == 0)
        #expect(session.synced == false)
    }

    /// Test Session Codable conformance
    @Test("Session: Encodes and decodes correctly")
    func testSessionCodable() throws {
        // Arrange
        let workoutPlanId = UUID()
        let feeling = PreWorkoutFeeling(rating: 4)
        let exerciseId = UUID()
        let exerciseLog = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: 100.0
        )

        let session = Session(
            workoutPlanId: workoutPlanId,
            preWorkoutFeeling: feeling,
            exerciseLogs: [exerciseLog],
            stats: SessionStats(totalVolume: 2400.0),
            synced: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Act
        let data = try encoder.encode(session)
        let decoded = try decoder.decode(Session.self, from: data)

        // Assert
        #expect(decoded.id == session.id)
        #expect(decoded.workoutPlanId == session.workoutPlanId)
        #expect(decoded.preWorkoutFeeling?.rating == 4)
        #expect(decoded.exerciseLogs.count == 1)
        #expect(decoded.stats.totalVolume == 2400.0)
        #expect(decoded.synced == true)
    }

    // MARK: - WorkoutPlan Tests

    /// Test WorkoutPlan initialization
    @Test("WorkoutPlan: Initializes correctly")
    func testWorkoutPlanInit() {
        // Arrange
        let exerciseIds = [UUID(), UUID(), UUID()]

        // Act
        let plan = WorkoutPlan(
            name: "Push Day",
            order: exerciseIds
        )

        // Assert
        #expect(plan.name == "Push Day")
        #expect(plan.order.count == 3)
        #expect(plan.order == exerciseIds)
    }

    /// Test WorkoutPlan Codable conformance
    @Test("WorkoutPlan: Encodes and decodes correctly")
    func testWorkoutPlanCodable() throws {
        // Arrange
        let exerciseIds = [UUID(), UUID()]
        let plan = WorkoutPlan(name: "Pull Day", order: exerciseIds)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(plan)
        let decoded = try decoder.decode(WorkoutPlan.self, from: data)

        // Assert
        #expect(decoded.id == plan.id)
        #expect(decoded.name == plan.name)
        #expect(decoded.order == plan.order)
    }

    // MARK: - ExerciseState Tests

    /// Test ExerciseState initialization
    @Test("ExerciseState: Initializes correctly")
    func testExerciseStateInit() {
        // Arrange
        let exerciseId = UUID()
        let date = Date()

        // Act
        let state = ExerciseState(
            exerciseId: exerciseId,
            lastStartLoad: 105.0,
            lastDecision: .up_1,
            lastUpdatedAt: date
        )

        // Assert
        #expect(state.exerciseId == exerciseId)
        #expect(state.lastStartLoad == 105.0)
        #expect(state.lastDecision == .up_1)
        #expect(state.lastUpdatedAt == date)
    }

    /// Test ExerciseState Codable conformance
    @Test("ExerciseState: Encodes and decodes correctly")
    func testExerciseStateCodable() throws {
        // Arrange
        let exerciseId = UUID()
        let state = ExerciseState(
            exerciseId: exerciseId,
            lastStartLoad: 110.0,
            lastDecision: .hold,
            lastUpdatedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Act
        let data = try encoder.encode(state)
        let decoded = try decoder.decode(ExerciseState.self, from: data)

        // Assert
        #expect(decoded.exerciseId == state.exerciseId)
        #expect(decoded.lastStartLoad == state.lastStartLoad)
        #expect(decoded.lastDecision == state.lastDecision)
        // Date comparison with small tolerance
        #expect(abs(decoded.lastUpdatedAt.timeIntervalSince(state.lastUpdatedAt)) < 1.0)
    }

    // MARK: - ExerciseCategory Enum Tests

    /// Test ExerciseCategory enum
    @Test("ExerciseCategory: Has correct cases")
    func testExerciseCategoryEnum() {
        // Assert
        #expect(ExerciseCategory.barbell.rawValue == "barbell")
        #expect(ExerciseCategory.dumbbell.rawValue == "dumbbell")
        #expect(ExerciseCategory.machine.rawValue == "machine")
        #expect(ExerciseCategory.bodyweight.rawValue == "bodyweight")
    }

    // MARK: - ExercisePriority Enum Tests

    /// Test ExercisePriority enum
    @Test("ExercisePriority: Has correct cases")
    func testExercisePriorityEnum() {
        // Assert
        #expect(ExercisePriority.upper.rawValue == "upper")
        #expect(ExercisePriority.lower.rawValue == "lower")
        #expect(ExercisePriority.accessory.rawValue == "accessory")
    }

    // MARK: - SessionStats Tests

    /// Test SessionStats initialization
    @Test("SessionStats: Initializes correctly")
    func testSessionStatsInit() {
        // Arrange & Act
        let stats = SessionStats(totalVolume: 3500.0)

        // Assert
        #expect(stats.totalVolume == 3500.0)
    }

    /// Test SessionStats Codable conformance
    @Test("SessionStats: Encodes and decodes correctly")
    func testSessionStatsCodable() throws {
        // Arrange
        let stats = SessionStats(totalVolume: 4200.0)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(stats)
        let decoded = try decoder.decode(SessionStats.self, from: data)

        // Assert
        #expect(decoded.totalVolume == stats.totalVolume)
    }
}
