import Testing
import Foundation
@testable import IncrementFeature

/*
 * PersistenceManagerTests
 *
 * Tests critical data persistence operations:
 * - Session save/load: Complete workout history must not be lost
 * - Exercise state save/load: Progression tracking between sessions
 *
 * These tests ensure users don't lose their workout data or progress
 * when the app closes or device restarts.
 */

@Suite("PersistenceManager Tests")
struct PersistenceManagerTests {

    /// Test saving and loading complete session data
    /// Critical: Sessions contain all workout history - data loss here is catastrophic
    @Test("PersistenceManager: Saves and loads sessions")
    func testSaveLoadSessions() async {
        // Arrange
        let manager = await PersistenceManager.shared
        // Clear before test to ensure isolation
        await manager.clearAll()

        let sessionId = UUID()
        let workoutPlanId = UUID()
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
            setLogs: [setLog]
        )

        let session = Session(
            id: sessionId,
            workoutPlanId: workoutPlanId,
            preWorkoutFeeling: PreWorkoutFeeling(rating: 4),
            exerciseLogs: [exerciseLog],
            stats: SessionStats(totalVolume: 800.0)
        )

        // Act - Save ONLY this session (replaces all)
        await manager.saveSessions([session])
        let loaded = await manager.loadSessions()

        // Assert
        #expect(loaded.count == 1, "Should have exactly one session after save")
        #expect(loaded[0].id == sessionId)
        #expect(loaded[0].workoutPlanId == workoutPlanId)
        #expect(loaded[0].exerciseLogs.count == 1)
        #expect(loaded[0].exerciseLogs[0].setLogs.count == 1)
        #expect(loaded[0].stats.totalVolume == 800.0)

        // Cleanup
        await manager.clearAll()
    }

    /// Test saving and loading exercise states (progression tracking)
    /// Critical: Exercise states track user's progression - losing this breaks the app's core value
    @Test("PersistenceManager: Saves and loads exercise states")
    func testSaveLoadExerciseStates() async {
        // Arrange
        let manager = await PersistenceManager.shared
        // Clear before test to ensure isolation
        await manager.clearAll()

        let exerciseId1 = UUID()
        let exerciseId2 = UUID()

        let state1 = ExerciseState(
            exerciseId: exerciseId1,
            lastStartLoad: 105.0,
            lastDecision: .up_1,
            lastUpdatedAt: Date()
        )

        let state2 = ExerciseState(
            exerciseId: exerciseId2,
            lastStartLoad: 225.0,
            lastDecision: .hold,
            lastUpdatedAt: Date()
        )

        let states = [
            exerciseId1: state1,
            exerciseId2: state2
        ]

        // Act - Save ONLY these states (replaces all)
        await manager.saveExerciseStates(states)
        let loaded = await manager.loadExerciseStates()

        // Assert
        #expect(loaded.count == 2, "Should have exactly two exercise states after save")
        #expect(loaded[exerciseId1]?.lastStartLoad == 105.0)
        #expect(loaded[exerciseId1]?.lastDecision == .up_1)
        #expect(loaded[exerciseId2]?.lastStartLoad == 225.0)
        #expect(loaded[exerciseId2]?.lastDecision == .hold)

        // Cleanup
        await manager.clearAll()
    }
}
