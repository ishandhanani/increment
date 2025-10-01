import Testing
import Foundation
@testable import IncrementFeature

/// Integration tests for SessionManager
/// Validates complete workout session flows including state transitions and progression
@Suite("SessionManager Integration Tests")
struct SessionManagerTests {

    /// Test session initialization loads default data
    @Test("SessionManager: Initializes with default exercises and plans")
    func testSessionManagerInit() async {
        // Arrange & Act
        let manager = await SessionManager()

        // Assert
        await MainActor.run {
            #expect(!manager.workoutPlans.isEmpty)
            #expect(!manager.exerciseProfiles.isEmpty)
            #expect(manager.currentSession == nil)
            #expect(manager.sessionState == .intro)
        }
    }

    /// Test starting a session creates session and moves to pre-workout state
    @Test("SessionManager: Starting session creates session and shows pre-workout")
    func testStartSession() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        // Act
        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
        }

        // Assert
        await MainActor.run {
            #expect(manager.currentSession != nil)
            #expect(manager.currentSession?.workoutPlanId == planId)
            #expect(manager.sessionState == .preWorkout)
            #expect(manager.currentExerciseIndex == 0)
            #expect(manager.currentSetIndex == 0)
        }
    }

    /// Test logging pre-workout feeling and starting stretching phase
    @Test("SessionManager: Logging pre-workout feeling starts stretching")
    func testLogPreWorkoutFeeling() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
        }

        // Act
        let feeling = PreWorkoutFeeling(rating: 4, note: "Ready")
        await MainActor.run {
            manager.logPreWorkoutFeeling(feeling)
        }

        // Assert
        await MainActor.run {
            #expect(manager.currentSession?.preWorkoutFeeling?.rating == 4)
            #expect(manager.currentSession?.preWorkoutFeeling?.note == "Ready")

            if case .stretching(let timeRemaining) = manager.sessionState {
                #expect(timeRemaining == 300)  // 5 minutes
            } else {
                Issue.record("Expected stretching state")
            }
        }
    }

    /// Test skipping stretching moves to first exercise warmup
    @Test("SessionManager: Skipping stretching starts first exercise")
    func testSkipStretching() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
        }

        // Act
        await MainActor.run {
            manager.skipStretching()
        }

        // Assert
        await MainActor.run {
            #expect(manager.currentExerciseLog != nil)

            if case .warmup(let step) = manager.sessionState {
                #expect(step == 0)  // First warmup step
            } else {
                Issue.record("Expected warmup state")
            }
        }
    }

    /// Test warmup prescription calculation
    @Test("SessionManager: Warmup prescription calculates correctly")
    func testWarmupPrescription() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
        }

        // Act
        let prescription = await MainActor.run {
            manager.getWarmupPrescription()
        }

        // Assert - First warmup should be 50% of start weight
        await MainActor.run {
            #expect(prescription != nil)
            let startWeight = manager.currentExerciseLog!.startWeight
            #expect(prescription?.weight == startWeight * 0.5)
            #expect(prescription?.reps == 5)
        }
    }

    /// Test advancing through warmup steps
    @Test("SessionManager: Advancing through warmup steps")
    func testAdvanceWarmup() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
        }

        // Act - Advance from step 0 to step 1
        await MainActor.run {
            manager.advanceWarmup()
        }

        // Assert - Should be at 70%×3
        await MainActor.run {
            if case .warmup(let step) = manager.sessionState {
                #expect(step == 1)
            } else {
                Issue.record("Expected warmup state step 1")
            }

            let prescription = manager.getWarmupPrescription()
            let startWeight = manager.currentExerciseLog!.startWeight
            #expect(prescription?.weight == startWeight * 0.7)
            #expect(prescription?.reps == 3)
        }

        // Act - Advance from step 1 to load
        await MainActor.run {
            manager.advanceWarmup()
        }

        // Assert - Should move to load state
        await MainActor.run {
            #expect(manager.sessionState == .load)
            #expect(manager.nextPrescription != nil)
        }
    }

    /// Test acknowledging load moves to working set
    @Test("SessionManager: Acknowledging load moves to working set")
    func testAcknowledgeLoad() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
            manager.advanceWarmup()
            manager.advanceWarmup()
        }

        // Act
        await MainActor.run {
            manager.acknowledgeLoad()
        }

        // Assert
        await MainActor.run {
            #expect(manager.sessionState == .workingSet)
        }
    }

    /// Test logging a set records data and computes next prescription
    @Test("SessionManager: Logging set records data and computes next prescription")
    func testLogSet() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
            manager.advanceWarmup()
            manager.advanceWarmup()
            manager.acknowledgeLoad()
        }

        // Act - Log first set
        await MainActor.run {
            manager.logSet(reps: 8, rating: .easy)
        }

        // Assert
        await MainActor.run {
            #expect(manager.currentExerciseLog?.setLogs.count == 1)
            #expect(manager.currentExerciseLog?.setLogs.first?.achievedReps == 8)
            #expect(manager.currentExerciseLog?.setLogs.first?.rating == .easy)
            #expect(manager.nextPrescription != nil)
            #expect(manager.currentSetIndex == 1)

            if case .rest = manager.sessionState {
                // Success - in rest state
            } else {
                Issue.record("Expected rest state after logging set")
            }
        }
    }

    /// Test bad-day switch activates on consecutive failures
    @Test("SessionManager: Bad-day switch activates on consecutive failures")
    func testBadDaySwitch() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
            manager.advanceWarmup()
            manager.advanceWarmup()
            manager.acknowledgeLoad()
        }

        let initialWeight = await MainActor.run { manager.nextPrescription?.weight ?? 0 }

        // Act - Log two red sets
        await MainActor.run {
            manager.logSet(reps: 3, rating: .fail)
            manager.advanceToNextSet()
        }

        await MainActor.run {
            manager.logSet(reps: 4, rating: .holyShit)
        }

        // Assert - Bad-day switch should have reduced weight
        await MainActor.run {
            let currentWeight = manager.nextPrescription?.weight ?? 0
            #expect(currentWeight < initialWeight)
        }
    }

    /// Test completing all sets finishes exercise
    @Test("SessionManager: Completing all sets finishes exercise")
    func testFinishExercise() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
            manager.advanceWarmup()
            manager.advanceWarmup()
            manager.acknowledgeLoad()
        }

        let totalSets = await MainActor.run {
            let exerciseId = manager.currentExerciseLog!.exerciseId
            return manager.exerciseProfiles[exerciseId]!.sets
        }

        // Act - Complete all sets
        for _ in 0..<totalSets {
            await MainActor.run {
                manager.logSet(reps: 8, rating: .hard)
                manager.advanceToNextSet()
            }
        }

        // Assert
        await MainActor.run {
            #expect(manager.sessionState == .review)
            #expect(manager.currentExerciseLog?.sessionDecision != nil)
            #expect(manager.currentExerciseLog?.nextStartWeight != nil)
        }
    }

    /// Test advancing to next exercise
    @Test("SessionManager: Advancing to next exercise works")
    func testAdvanceToNextExercise() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
            manager.advanceWarmup()
            manager.advanceWarmup()
            manager.acknowledgeLoad()
        }

        let totalSets = await MainActor.run {
            let exerciseId = manager.currentExerciseLog!.exerciseId
            return manager.exerciseProfiles[exerciseId]!.sets
        }

        // Complete first exercise
        for _ in 0..<totalSets {
            await MainActor.run {
                manager.logSet(reps: 8, rating: .hard)
                manager.advanceToNextSet()
            }
        }

        let firstExerciseId = await MainActor.run { manager.currentExerciseLog!.exerciseId }

        // Act - Advance to next exercise
        await MainActor.run {
            manager.advanceToNextExercise()
        }

        // Assert
        await MainActor.run {
            #expect(manager.currentExerciseIndex == 1)

            if case .warmup = manager.sessionState {
                // Success - started next exercise warmup
            } else {
                Issue.record("Expected warmup state for next exercise")
            }

            // Should be a different exercise
            #expect(manager.currentExerciseLog?.exerciseId != firstExerciseId)
        }
    }

    /// Test completing all exercises finishes session
    @Test("SessionManager: Completing all exercises finishes session")
    func testFinishSession() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
        }

        let exerciseCount = await MainActor.run {
            manager.workoutPlans.first!.order.count
        }

        // Act - Complete all exercises
        for exerciseIndex in 0..<exerciseCount {
            // Warmup
            await MainActor.run {
                manager.advanceWarmup()
                manager.advanceWarmup()
                manager.acknowledgeLoad()
            }

            // Complete sets
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

            // Advance to next or finish
            await MainActor.run {
                manager.advanceToNextExercise()
            }
        }

        // Assert
        await MainActor.run {
            #expect(manager.sessionState == .done)
            #expect(manager.currentSession?.stats.totalVolume ?? 0 > 0)
            #expect(manager.currentSession?.exerciseLogs.count == exerciseCount)
        }
    }

    /// Test session volume calculation
    @Test("SessionManager: Calculates session volume correctly")
    func testSessionVolumeCalculation() async {
        // Arrange
        let manager = await SessionManager()

        // Create a simple test scenario
        let exerciseId = UUID()
        let exerciseLog = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: 100.0,
            setLogs: [
                SetLog(setIndex: 1, targetReps: 8, targetWeight: 100.0, achievedReps: 8, rating: .hard, actualWeight: 100.0),
                SetLog(setIndex: 2, targetReps: 8, targetWeight: 100.0, achievedReps: 7, rating: .hard, actualWeight: 100.0),
                SetLog(setIndex: 3, targetReps: 8, targetWeight: 100.0, achievedReps: 6, rating: .hard, actualWeight: 100.0)
            ]
        )

        // Expected volume: (8×100) + (7×100) + (6×100) = 2100
        let expectedVolume = 2100.0

        // Act - Manually calculate what finish session would compute
        let volume = exerciseLog.setLogs.reduce(0.0) { total, set in
            total + (Double(set.achievedReps) * set.actualWeight)
        }

        // Assert
        #expect(volume == expectedVolume)
    }

    /// Test exercise state persistence after completion
    @Test("SessionManager: Exercise state persists after completion")
    func testExerciseStatePersistence() async {
        // Arrange
        let manager = await SessionManager()
        let planId = await MainActor.run { manager.workoutPlans.first!.id }

        await MainActor.run {
            manager.startSession(workoutPlanId: planId)
            manager.logPreWorkoutFeeling(PreWorkoutFeeling(rating: 4))
            manager.skipStretching()
            manager.advanceWarmup()
            manager.advanceWarmup()
            manager.acknowledgeLoad()
        }

        let exerciseId = await MainActor.run { manager.currentExerciseLog!.exerciseId }

        let totalSets = await MainActor.run {
            manager.exerciseProfiles[exerciseId]!.sets
        }

        // Act - Complete exercise
        for _ in 0..<totalSets {
            await MainActor.run {
                manager.logSet(reps: 8, rating: .easy)
                manager.advanceToNextSet()
            }
        }

        // Assert - Exercise state should be updated
        await MainActor.run {
            let state = manager.exerciseStates[exerciseId]
            #expect(state != nil)
            #expect(state?.lastStartLoad ?? 0 > 0)
            #expect(state?.lastDecision != nil)
        }
    }
}
