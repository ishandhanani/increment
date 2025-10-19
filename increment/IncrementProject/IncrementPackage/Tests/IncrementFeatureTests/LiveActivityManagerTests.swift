import Testing
import ActivityKit
@testable import IncrementFeature

@Suite("LiveActivityManager Tests")
struct LiveActivityManagerTests {

    @Test("Manager is a singleton")
    func testSingleton() async {
        let instance1 = await LiveActivityManager.shared
        let instance2 = await LiveActivityManager.shared

        #expect(instance1 === instance2)
    }

    @Test("Activity starts with correct initial state")
    func testActivityStartsWithCorrectState() async {
        let manager = await LiveActivityManager.shared

        await manager.startActivity(
            workoutName: "Test Workout",
            exerciseId: "Bench Press",
            currentSet: 1,
            totalSets: 3,
            nextWeight: 135.0,
            nextReps: 8,
            exercisesCompleted: 0,
            totalExercises: 5
        )

        let hasActive = await manager.hasActiveActivity
        #expect(hasActive)

        // Clean up
        await manager.endActivity()
    }

    @Test("Update activity with rest timer")
    func testUpdateActivityWithRestTimer() async {
        let manager = await LiveActivityManager.shared

        // Start activity first
        await manager.startActivity(
            workoutName: "Test Workout",
            exerciseId: "Squat",
            currentSet: 1,
            totalSets: 4,
            nextWeight: 225.0,
            nextReps: 5,
            exercisesCompleted: 1,
            totalExercises: 5
        )

        // Update with rest timer
        await manager.updateActivity(
            exerciseId: "Squat",
            currentSet: 2,
            totalSets: 4,
            restTimeRemaining: 90,
            nextWeight: 225.0,
            nextReps: 5,
            isResting: true,
            exercisesCompleted: 1,
            totalExercises: 5
        )

        // Verify activity is still active
        let hasActive = await manager.hasActiveActivity
        #expect(hasActive)

        // Clean up
        await manager.endActivity()
    }

    @Test("End activity clears current activity")
    func testEndActivityClearsState() async {
        let manager = await LiveActivityManager.shared

        await manager.startActivity(
            workoutName: "Test Workout",
            exerciseId: "Deadlift",
            currentSet: 1,
            totalSets: 3,
            nextWeight: 315.0,
            nextReps: 5,
            exercisesCompleted: 2,
            totalExercises: 5
        )

        #expect(await manager.hasActiveActivity)

        await manager.endActivity(
            finalExercise: "Deadlift",
            completedExercises: 5,
            totalExercises: 5
        )

        #expect(await !manager.hasActiveActivity)
    }

    @Test("Multiple updates are serialized to prevent race conditions")
    func testSerializedUpdates() async {
        let manager = await LiveActivityManager.shared

        await manager.startActivity(
            workoutName: "Test Workout",
            exerciseId: "Overhead Press",
            currentSet: 1,
            totalSets: 3,
            nextWeight: 95.0,
            nextReps: 8,
            exercisesCompleted: 3,
            totalExercises: 5
        )

        // Fire multiple updates rapidly
        async let update1: Void = manager.updateActivity(
            exerciseId: "Overhead Press",
            currentSet: 1,
            totalSets: 3,
            restTimeRemaining: 90,
            nextWeight: 95.0,
            nextReps: 8,
            isResting: true,
            exercisesCompleted: 3,
            totalExercises: 5
        )

        async let update2: Void = manager.updateActivity(
            exerciseId: "Overhead Press",
            currentSet: 1,
            totalSets: 3,
            restTimeRemaining: 89,
            nextWeight: 95.0,
            nextReps: 8,
            isResting: true,
            exercisesCompleted: 3,
            totalExercises: 5
        )

        async let update3: Void = manager.updateActivity(
            exerciseId: "Overhead Press",
            currentSet: 1,
            totalSets: 3,
            restTimeRemaining: 88,
            nextWeight: 95.0,
            nextReps: 8,
            isResting: true,
            exercisesCompleted: 3,
            totalExercises: 5
        )

        // All updates should complete without conflicts
        _ = await (update1, update2, update3)

        #expect(await manager.hasActiveActivity)

        // Clean up
        await manager.endActivity()
    }

    @Test("Starting new activity ends previous activity")
    func testStartingNewActivityEndsPrevious() async {
        let manager = await LiveActivityManager.shared

        // Start first activity
        await manager.startActivity(
            workoutName: "Morning Workout",
            exerciseId: "Bench Press",
            currentSet: 1,
            totalSets: 3,
            nextWeight: 135.0,
            nextReps: 8,
            exercisesCompleted: 0,
            totalExercises: 5
        )

        #expect(await manager.hasActiveActivity)

        // Start second activity (should end first)
        await manager.startActivity(
            workoutName: "Evening Workout",
            exerciseId: "Squat",
            currentSet: 1,
            totalSets: 4,
            nextWeight: 225.0,
            nextReps: 5,
            exercisesCompleted: 0,
            totalExercises: 4
        )

        #expect(await manager.hasActiveActivity)

        // Clean up
        await manager.endActivity()
    }

    @Test("Update without active activity handles gracefully")
    func testUpdateWithoutActiveActivity() async {
        let manager = await LiveActivityManager.shared

        // Ensure no active activity
        await manager.endActivity()

        // Try to update - should not crash
        await manager.updateActivity(
            exerciseId: "Squat",
            currentSet: 2,
            totalSets: 4,
            restTimeRemaining: 90,
            nextWeight: 225.0,
            nextReps: 5,
            isResting: true,
            exercisesCompleted: 1,
            totalExercises: 5
        )

        // Should still have no active activity
        #expect(await !manager.hasActiveActivity)
    }
}
