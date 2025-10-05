import ActivityKit
import Foundation

/// Manages Live Activities for workout sessions
@MainActor
public class LiveActivityManager {
    public static let shared = LiveActivityManager()

    private var currentActivity: Activity<WorkoutLiveActivityAttributes>?
    private let updateQueue = DispatchQueue(label: "com.increment.liveactivity.updates", qos: .userInitiated)

    private init() {}

    /// Start a Live Activity for the workout session
    public func startActivity(
        workoutName: String,
        exerciseName: String,
        currentSet: Int,
        totalSets: Int,
        nextWeight: Double,
        nextReps: Int,
        exercisesCompleted: Int,
        totalExercises: Int
    ) async {
        // Check notification authorization before starting activity
        let notificationManager = NotificationManager.shared
        let isAuthorized = await notificationManager.isAuthorized()

        if !isAuthorized {
            // Request authorization if not already granted
            _ = await notificationManager.requestAuthorization()
        }

        // End any existing activity first
        await endActivity()

        let attributes = WorkoutLiveActivityAttributes(workoutName: workoutName)

        let initialState = WorkoutLiveActivityAttributes.ContentState(
            currentExercise: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets,
            restTimeRemaining: nil,
            nextWeight: nextWeight,
            nextReps: nextReps,
            isResting: false,
            exercisesCompleted: exercisesCompleted,
            totalExercises: totalExercises
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil)
            )
            currentActivity = activity
            print("✅ Live Activity started: \(activity.id)")
        } catch {
            print("❌ Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    /// Update the Live Activity with new state (serialized to prevent race conditions)
    public func updateActivity(
        exerciseName: String,
        currentSet: Int,
        totalSets: Int,
        restTimeRemaining: Int?,
        nextWeight: Double,
        nextReps: Int,
        isResting: Bool,
        exercisesCompleted: Int,
        totalExercises: Int
    ) async {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to update")
            return
        }

        // Serialize updates to prevent race conditions
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            updateQueue.async { [weak activity] in
                Task { @MainActor in
                    guard let activity = activity else {
                        continuation.resume()
                        return
                    }

                    let updatedState = WorkoutLiveActivityAttributes.ContentState(
                        currentExercise: exerciseName,
                        currentSet: currentSet,
                        totalSets: totalSets,
                        restTimeRemaining: restTimeRemaining,
                        nextWeight: nextWeight,
                        nextReps: nextReps,
                        isResting: isResting,
                        exercisesCompleted: exercisesCompleted,
                        totalExercises: totalExercises
                    )

                    await activity.update(
                        ActivityContent<WorkoutLiveActivityAttributes.ContentState>(
                            state: updatedState,
                            staleDate: nil
                        )
                    )
                    print("🔄 Live Activity updated")
                    continuation.resume()
                }
            }
        }
    }

    /// End the Live Activity with meaningful final state
    public func endActivity(
        finalExercise: String? = nil,
        completedExercises: Int = 0,
        totalExercises: Int = 0
    ) async {
        guard let activity = currentActivity else { return }

        let finalState = WorkoutLiveActivityAttributes.ContentState(
            currentExercise: finalExercise ?? "Workout Complete",
            currentSet: 0,
            totalSets: 0,
            restTimeRemaining: nil,
            nextWeight: 0,
            nextReps: 0,
            isResting: false,
            exercisesCompleted: completedExercises,
            totalExercises: totalExercises
        )

        await activity.end(
            ActivityContent<WorkoutLiveActivityAttributes.ContentState>(
                state: finalState,
                staleDate: nil
            ),
            dismissalPolicy: .after(.now + 5)
        )

        currentActivity = nil
        print("🛑 Live Activity ended")
    }

    /// Check if there's an active Live Activity
    public var hasActiveActivity: Bool {
        currentActivity != nil
    }
}
