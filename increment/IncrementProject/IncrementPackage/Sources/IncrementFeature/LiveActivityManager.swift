#if os(iOS)
@preconcurrency import ActivityKit
#endif
import Foundation
import OSLog

/// Manages Live Activities for workout sessions
@MainActor
public class LiveActivityManager {
    public static let shared = LiveActivityManager()

    #if os(iOS)
    private var currentActivity: Activity<WorkoutLiveActivityAttributes>?
    #endif

    private init() {}

    /// Start a Live Activity for the workout session
    public func startActivity(
        workoutName: String,
        exerciseId: String,
        currentSet: Int,
        totalSets: Int,
        nextWeight: Double,
        nextReps: Int,
        exercisesCompleted: Int,
        totalExercises: Int
    ) async {
        #if os(iOS)
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
            currentExercise: exerciseId,
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
            AppLogger.liveActivity.notice("Live Activity started")
        } catch {
            AppLogger.liveActivity.error("Failed to start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    /// Update the Live Activity with new state
    public func updateActivity(
        exerciseId: String,
        currentSet: Int,
        totalSets: Int,
        restTimeRemaining: Int?,
        nextWeight: Double,
        nextReps: Int,
        isResting: Bool,
        exercisesCompleted: Int,
        totalExercises: Int
    ) async {
        #if os(iOS)
        guard let activity = currentActivity else {
            AppLogger.liveActivity.debug("No active Live Activity to update")
            return
        }

        let updatedState = WorkoutLiveActivityAttributes.ContentState(
            currentExercise: exerciseId,
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
        AppLogger.liveActivity.debug("Live Activity updated")
        #endif
    }

    /// End the Live Activity with meaningful final state
    public func endActivity(
        finalExercise: String? = nil,
        completedExercises: Int = 0,
        totalExercises: Int = 0
    ) async {
        #if os(iOS)
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
        AppLogger.liveActivity.notice("Live Activity ended")
        #endif
    }

    /// Check if there's an active Live Activity
    public var hasActiveActivity: Bool {
        #if os(iOS)
        return currentActivity != nil
        #else
        return false
        #endif
    }
}