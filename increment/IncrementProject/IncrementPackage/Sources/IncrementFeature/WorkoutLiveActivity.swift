import ActivityKit
import Foundation

/// Activity attributes for workout Live Activities
public struct WorkoutLiveActivityAttributes: ActivityAttributes {
    /// Static data that doesn't change during the activity
    public let workoutName: String

    public struct ContentState: Codable, Hashable {
        /// Current exercise name
        public var currentExercise: String

        /// Current set number (1-indexed)
        public var currentSet: Int

        /// Total number of sets for current exercise
        public var totalSets: Int

        /// Rest time remaining in seconds (nil if not resting)
        public var restTimeRemaining: Int?

        /// Next prescription weight
        public var nextWeight: Double

        /// Next prescription reps
        public var nextReps: Int

        /// Whether currently in rest period
        public var isResting: Bool

        /// Total exercises completed
        public var exercisesCompleted: Int

        /// Total exercises in workout
        public var totalExercises: Int

        public init(
            currentExercise: String,
            currentSet: Int,
            totalSets: Int,
            restTimeRemaining: Int?,
            nextWeight: Double,
            nextReps: Int,
            isResting: Bool,
            exercisesCompleted: Int,
            totalExercises: Int
        ) {
            self.currentExercise = currentExercise
            self.currentSet = currentSet
            self.totalSets = totalSets
            self.restTimeRemaining = restTimeRemaining
            self.nextWeight = nextWeight
            self.nextReps = nextReps
            self.isResting = isResting
            self.exercisesCompleted = exercisesCompleted
            self.totalExercises = totalExercises
        }
    }

    public init(workoutName: String) {
        self.workoutName = workoutName
    }
}