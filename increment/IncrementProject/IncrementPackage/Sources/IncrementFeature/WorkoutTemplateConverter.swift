import Foundation

/// Utilities to convert between new workout models and existing STEEL models
struct WorkoutTemplateConverter {

    /// Converts a Lift and WorkoutExercise to an ExerciseProfile (STEEL runtime config)
    static func toExerciseProfile(from workoutExercise: WorkoutExercise) -> ExerciseProfile {
        let lift = workoutExercise.lift

        return ExerciseProfile(
            exerciseId: lift.id,
            name: lift.name,
            equipment: lift.equipment,
            priority: workoutExercise.priority,
            repRange: lift.steelConfig.repRange,
            sets: workoutExercise.targetSets,
            baseIncrement: lift.steelConfig.baseIncrement,
            rounding: lift.steelConfig.rounding,
            microAdjustStep: lift.steelConfig.microAdjustStep,
            weeklyCapPct: lift.steelConfig.weeklyCapPct,
            plateOptions: lift.steelConfig.plateOptions,
            warmupRule: lift.steelConfig.warmupRule,
            defaultRestSec: Int(workoutExercise.restTime)
        )
    }

    /// Converts a WorkoutTemplate to dictionary of ExerciseProfiles
    /// Returns: [String: ExerciseProfile] keyed by exercise ID
    static func toExerciseProfiles(from template: WorkoutTemplate) -> [String: ExerciseProfile] {
        var profiles: [String: ExerciseProfile] = [:]

        // Convert each WorkoutExercise to an ExerciseProfile
        for workoutExercise in template.exercises.sorted(by: { $0.order < $1.order }) {
            let profile = toExerciseProfile(from: workoutExercise)
            profiles[workoutExercise.lift.id] = profile  // Key by lift.id
        }

        return profiles
    }
}
