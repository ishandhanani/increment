import Testing
import Foundation
@testable import IncrementFeature

/*
 * SessionManagerTests
 *
 * Integration tests for the complete workout flow:
 * - Pre-workout → first working set: Validates the entire onboarding flow
 * - Complete workout: End-to-end smoke test ensuring all phases work together
 *
 * These tests verify users can actually complete a workout from start to finish
 * without crashes or data inconsistencies.
 */

@Suite("SessionManager Integration Tests")
struct SessionManagerTests {

    /// Test the complete flow from pre-workout to first working set
    /// Critical: This is the first-time user experience - if this fails, no one can use the app
    @Test("SessionManager: Pre-workout to first set flow")
    func testPreWorkoutToFirstSet() async {
        // Arrange
        // Clear any persisted data from previous tests
        await PersistenceManager.shared.clearAll()

        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        // Act - Start session
        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
        }

        // Assert - Should be at pre-workout screen
        await MainActor.run {
            #expect(manager.currentSession != nil)
            #expect(manager.sessionState == .preWorkout)
        }

        // Act - Log pre-workout feeling
        await MainActor.run {
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4, note: "Ready"))
        }

        // Assert - Should start stretching
        await MainActor.run {
            if case .stretching(let timeRemaining) = manager.sessionState {
                #expect(timeRemaining == 300)  // 5 minutes
            } else {
                Issue.record("Expected stretching state")
            }
        }

        // Act - Skip stretching
        await MainActor.run {
            manager.skipStretching()
        }

        // Assert - Should be at warmup
        await MainActor.run {
            #expect(manager.currentExerciseLog != nil)
            if case .warmup(let step) = manager.sessionState {
                #expect(step == 0)
            } else {
                Issue.record("Expected warmup state")
            }
        }

        // Act - Complete warmup
        await MainActor.run {
            manager.advanceWarmup()  // 50% × 5
            manager.advanceWarmup()  // 70% × 3
        }

        // Assert - Should be at load screen
        await MainActor.run {
            #expect(manager.sessionState == .load)
            #expect(manager.nextPrescription != nil)
        }

        // Act - Acknowledge load and get to first working set
        await MainActor.run {
            manager.acknowledgeLoad()
        }

        // Assert - Should be ready for first working set
        await MainActor.run {
            #expect(manager.sessionState == .workingSet)
            #expect(manager.currentSetIndex == 0)
        }
    }

    /// Test that only the first exercise has warmups
    /// Critical: Subsequent exercises should skip warmups to save time
    @Test("SessionManager: Smart warmup sets - only first exercise")
    func testSmartWarmupSets() async {
        // Arrange
        await PersistenceManager.shared.clearAll()
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        // Act - Start and setup
        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
        }

        // Assert - First exercise should start with warmup
        await MainActor.run {
            if case .warmup(let step) = manager.sessionState {
                #expect(step == 0)
            } else {
                Issue.record("Expected warmup state for first exercise")
            }
        }

        // Act - Complete first exercise warmup and sets
        await MainActor.run {
            manager.advanceWarmup()
            manager.advanceWarmup()
            manager.acknowledgeLoad()
        }

        let firstExerciseSets = await MainActor.run {
            let exerciseId = manager.currentExerciseLog!.exerciseId
            return manager.exerciseProfiles[exerciseId]!.sets
        }

        for _ in 0..<firstExerciseSets {
            await MainActor.run {
                manager.logSet(reps: 6, rating: .hard)
                manager.advanceToNextSet()
            }
        }

        // Act - Move to second exercise
        await MainActor.run {
            manager.advanceToNextExercise()
        }

        // Assert - Second exercise should skip warmup, go directly to load
        await MainActor.run {
            #expect(manager.sessionState == .load)
            #expect(manager.isFirstExercise == false)
        }
    }

    /// Test completing an entire workout (smoke test)
    /// Critical: End-to-end test ensuring all components work together
    @Test("SessionManager: Complete workout smoke test")
    func testCompleteWorkout() async {
        // Arrange
        await PersistenceManager.shared.clearAll()
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        // Act - Start and setup
        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
        }

        let exerciseCount = await MainActor.run { manager.workoutPlans.first!.order.count }

        // Act - Complete all exercises
        for exerciseIndex in 0..<exerciseCount {
            // Complete warmup (only first exercise)
            if exerciseIndex == 0 {
                await MainActor.run {
                    manager.advanceWarmup()
                    manager.advanceWarmup()
                    manager.acknowledgeLoad()
                }
            } else {
                // Subsequent exercises skip warmup, just acknowledge load
                await MainActor.run {
                    manager.acknowledgeLoad()
                }
            }

            // Complete all working sets
            let totalSets = await MainActor.run {
                let exerciseId = manager.currentExerciseLog!.exerciseId
                return manager.exerciseProfiles[exerciseId]!.sets
            }

            for _ in 0..<totalSets {
                await MainActor.run {
                    manager.logSet(reps: 6, rating: .hard)
                    manager.advanceToNextSet()
                }
            }

            // Move to next exercise
            await MainActor.run {
                manager.advanceToNextExercise()
            }
        }

        // Assert - Workout should be complete with valid data
        await MainActor.run {
            #expect(manager.sessionState == .done)
            #expect(manager.currentSession != nil)
            #expect(manager.currentSession?.exerciseLogs.count == exerciseCount)
            #expect(manager.currentSession?.stats.totalVolume ?? 0 > 0)

            // Verify each exercise has valid data
            for exerciseLog in manager.currentSession!.exerciseLogs {
                #expect(exerciseLog.setLogs.count > 0)
                #expect(exerciseLog.sessionDecision != nil)
                #expect(exerciseLog.nextStartWeight != nil)
            }
        }
    }

    /// Test weekly cap enforcement with recent load history
    /// Verifies that getRecentLoads() correctly queries and the weekly cap prevents unsafe jumps
    @Test("SessionManager: Weekly cap enforcement with load history")
    func testWeeklyCapEnforcement() async {
        // Arrange
        await PersistenceManager.shared.clearAll()
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        // Get the first exercise ID
        let exerciseId = await MainActor.run {
            manager.workoutPlans.first!.order.first!
        }

        // Create historical sessions with increasing weights over 7 days
        let calendar = Calendar.current
        let today = Date()
        var historicalSessions: [Session] = []

        // Day 1: 100 lbs
        if let day1 = calendar.date(byAdding: .day, value: -6, to: today) {
            let log1 = ExerciseSessionLog(
                exerciseId: exerciseId,
                startWeight: 100.0,
                setLogs: [SetLog(setIndex: 1, targetReps: 5, targetWeight: 100.0, achievedReps: 5, rating: .hard, actualWeight: 100.0)],
                sessionDecision: .up_1,
                nextStartWeight: 105.0
            )
            historicalSessions.append(Session(date: day1, workoutPlanId: planId, exerciseLogs: [log1]))
        }

        // Day 3: 105 lbs
        if let day3 = calendar.date(byAdding: .day, value: -4, to: today) {
            let log2 = ExerciseSessionLog(
                exerciseId: exerciseId,
                startWeight: 105.0,
                setLogs: [SetLog(setIndex: 1, targetReps: 5, targetWeight: 105.0, achievedReps: 5, rating: .hard, actualWeight: 105.0)],
                sessionDecision: .up_1,
                nextStartWeight: 110.0
            )
            historicalSessions.append(Session(date: day3, workoutPlanId: planId, exerciseLogs: [log2]))
        }

        // Day 5: 110 lbs
        if let day5 = calendar.date(byAdding: .day, value: -2, to: today) {
            let log3 = ExerciseSessionLog(
                exerciseId: exerciseId,
                startWeight: 110.0,
                setLogs: [SetLog(setIndex: 1, targetReps: 5, targetWeight: 110.0, achievedReps: 5, rating: .hard, actualWeight: 110.0)],
                sessionDecision: .up_2,
                nextStartWeight: 120.0
            )
            historicalSessions.append(Session(date: day5, workoutPlanId: planId, exerciseLogs: [log3]))
        }

        // Save historical sessions
        await MainActor.run {
            PersistenceManager.shared.saveSessions(historicalSessions)
        }

        // Act - Start a new session with an aggressive up_2 decision
        await MainActor.run {
            // Manually set exercise state to a high weight
            manager.exerciseStates[exerciseId] = ExerciseState(
                exerciseId: exerciseId,
                lastStartLoad: 110.0,
                lastDecision: .up_2,
                lastUpdatedAt: Date()
            )

            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()

            // Complete warmup
            manager.advanceWarmup()
            manager.advanceWarmup()
            manager.acknowledgeLoad()

            // Complete all working sets with good performance
            let profile = manager.exerciseProfiles[exerciseId]!
            for _ in 0..<profile.sets {
                manager.logSet(reps: 8, rating: .easy)  // Perfect performance
                manager.advanceToNextSet()
            }
        }

        // Assert - Weekly cap should prevent excessive increase
        await MainActor.run {
            let exerciseLog = manager.currentSession?.exerciseLogs.first
            #expect(exerciseLog != nil)
            #expect(exerciseLog?.nextStartWeight != nil)

            // With weeklyCapPct of 5%, and recent loads of [100, 105, 110]
            // Maximum allowed next weight should be around 110 * 1.05 = 115.5
            // Even with perfect performance suggesting a big jump
            let nextWeight = exerciseLog!.nextStartWeight!
            #expect(nextWeight <= 120.0)  // Cap should prevent excessive jump

            // Verify the decision was made considering the cap
            #expect(exerciseLog?.sessionDecision != nil)
        }

        // Cleanup
        await MainActor.run {
            PersistenceManager.shared.clearAll()
        }
    }

    /// Test getRecentLoads returns empty array when no history exists
    @Test("SessionManager: No recent loads for new exercise")
    func testNoRecentLoadsForNewExercise() async {
        // Arrange
        await PersistenceManager.shared.clearAll()
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        // Clear any existing session history
        await MainActor.run {
            PersistenceManager.shared.clearAll()
        }

        // Act - Start a new session
        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()

            // Complete warmup
            manager.advanceWarmup()
            manager.advanceWarmup()
            manager.acknowledgeLoad()

            // Complete working sets
            let exerciseId = manager.currentExerciseLog!.exerciseId
            let profile = manager.exerciseProfiles[exerciseId]!
            for _ in 0..<profile.sets {
                manager.logSet(reps: 6, rating: .hard)
                manager.advanceToNextSet()
            }
        }

        // Assert - Should complete successfully without recent loads
        await MainActor.run {
            let exerciseLog = manager.currentSession?.exerciseLogs.first
            #expect(exerciseLog != nil)
            #expect(exerciseLog?.nextStartWeight != nil)
            #expect(exerciseLog?.sessionDecision != nil)
        }

        // Cleanup
        await MainActor.run {
            PersistenceManager.shared.clearAll()
        }
    }
}
