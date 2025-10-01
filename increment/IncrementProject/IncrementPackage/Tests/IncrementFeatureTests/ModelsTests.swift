import Testing
import Foundation
@testable import IncrementFeature

/*
 * ModelsTests
 *
 * Tests critical data model serialization for:
 * - Session: Complete workout data including exercises, stats, and pre-workout state
 * - ExerciseProfile: Exercise configuration with progression parameters
 * - SetLog: Individual set performance data
 *
 * These tests ensure workout data persists correctly and can be loaded
 * after app restart without data loss or corruption.
 */

@Suite("Models Tests")
struct ModelsTests {

    // MARK: - Session Codable Test

    /// Test Session encodes and decodes correctly with all nested data
    /// Critical: Session is the main data structure saved after each workout
    @Test("Session: Encodes and decodes with nested data")
    func testSessionCodable() throws {
        // Arrange
        let workoutPlanId = UUID()
        let feeling = PreWorkoutFeeling(rating: 4, note: "Feeling strong")
        let exerciseId = UUID()

        let setLog = SetLog(
            setIndex: 1,
            targetReps: 8,
            targetWeight: 100.0,
            achievedReps: 8,
            rating: .hard,
            actualWeight: 100.0
        )

        let exerciseLog = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: 100.0,
            setLogs: [setLog],
            sessionDecision: .up_1,
            nextStartWeight: 105.0
        )

        let session = Session(
            workoutPlanId: workoutPlanId,
            preWorkoutFeeling: feeling,
            exerciseLogs: [exerciseLog],
            stats: SessionStats(totalVolume: 800.0),
            synced: false
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
        #expect(decoded.preWorkoutFeeling?.note == "Feeling strong")
        #expect(decoded.exerciseLogs.count == 1)
        #expect(decoded.exerciseLogs[0].startWeight == 100.0)
        #expect(decoded.exerciseLogs[0].setLogs.count == 1)
        #expect(decoded.exerciseLogs[0].sessionDecision == .up_1)
        #expect(decoded.stats.totalVolume == 800.0)
    }

    // MARK: - ExerciseProfile Codable Test

    /// Test ExerciseProfile encodes and decodes correctly with all parameters
    /// Critical: ExerciseProfile defines progression rules that must persist
    @Test("ExerciseProfile: Encodes and decodes with all parameters")
    func testExerciseProfileCodable() throws {
        // Arrange
        let profile = ExerciseProfile(
            name: "Barbell Bench Press",
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

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(profile)
        let decoded = try decoder.decode(ExerciseProfile.self, from: data)

        // Assert
        #expect(decoded.id == profile.id)
        #expect(decoded.name == profile.name)
        #expect(decoded.category == .barbell)
        #expect(decoded.priority == .upper)
        #expect(decoded.repRange == 5...8)
        #expect(decoded.sets == 3)
        #expect(decoded.baseIncrement == 5.0)
        #expect(decoded.rounding == 2.5)
        #expect(decoded.microAdjustStep == 2.5)
        #expect(decoded.weeklyCapPct == 5.0)
        #expect(decoded.plateOptions == [45, 25, 10, 5, 2.5])
        #expect(decoded.warmupRule == "ramped_2")
        #expect(decoded.defaultRestSec == 90)
    }

    // MARK: - SetLog Codable Test

    /// Test SetLog encodes and decodes correctly
    /// Critical: SetLog captures performance data for progression decisions
    @Test("SetLog: Encodes and decodes correctly")
    func testSetLogCodable() throws {
        // Arrange
        let setLog = SetLog(
            setIndex: 2,
            targetReps: 8,
            targetWeight: 95.0,
            achievedReps: 7,
            rating: .hard,
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
        #expect(decoded.setIndex == 2)
        #expect(decoded.targetReps == 8)
        #expect(decoded.targetWeight == 95.0)
        #expect(decoded.achievedReps == 7)
        #expect(decoded.rating == .hard)
        #expect(decoded.actualWeight == 95.0)
        #expect(decoded.restPlannedSec == 120)
    }
}
