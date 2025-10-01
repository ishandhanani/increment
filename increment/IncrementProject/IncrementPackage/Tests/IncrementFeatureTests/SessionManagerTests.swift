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
}
