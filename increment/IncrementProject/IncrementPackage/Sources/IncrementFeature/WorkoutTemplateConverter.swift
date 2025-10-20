import Foundation

/// Utilities to convert between new workout models and existing STEEL models
struct WorkoutTemplateConverter {

    /// Converts a Lift to an ExerciseProfile (maintaining STEEL compatibility)
    /// Returns nil for cardio exercises (which use CardioConfig instead)
    static func toExerciseProfile(from lift: Lift, sets: Int, restSec: Int) -> ExerciseProfile? {
        // Skip cardio exercises - they don't use ExerciseProfile
        guard let steelConfig = lift.steelConfig else {
            return nil
        }
        
        // Map new Equipment to old ExerciseCategory
        let category: ExerciseCategory = {
            switch lift.equipment {
            case .barbell:
                return .barbell
            case .dumbbell:
                return .dumbbell
            case .machine:
                return .machine
            case .bodyweight, .cable, .cardioMachine:
                return .bodyweight
            }
        }()

        // Map new LiftPriority to old ExercisePriority
        let priority: ExercisePriority = {
            switch lift.category {
            case .push, .pull:
                return .upper
            case .legs:
                return .lower
            case .cardio:
                return .accessory
            }
        }()

        return ExerciseProfile(
            name: lift.name,
            category: category,
            priority: priority,
            repRange: steelConfig.repRange,
            sets: sets,
            baseIncrement: steelConfig.baseIncrement,
            rounding: steelConfig.rounding,
            microAdjustStep: steelConfig.microAdjustStep,
            weeklyCapPct: steelConfig.weeklyCapPct,
            plateOptions: steelConfig.plateOptions,
            warmupRule: steelConfig.warmupRule,
            defaultRestSec: restSec
        )
    }

    /// Converts a WorkoutTemplate to dictionary of ExerciseProfiles
    /// Returns: [String: ExerciseProfile] keyed by exercise ID
    /// Note: Skips cardio exercises (which use CardioConfig instead)
    static func toExerciseProfiles(from template: WorkoutTemplate) -> [String: ExerciseProfile] {
        var profiles: [String: ExerciseProfile] = [:]

        // Convert each WorkoutExercise to an ExerciseProfile
        for workoutExercise in template.exercises.sorted(by: { $0.order < $1.order }) {
            if let profile = toExerciseProfile(
                from: workoutExercise.lift,
                sets: workoutExercise.targetSets,
                restSec: Int(workoutExercise.restTime)
            ) {
                profiles[workoutExercise.lift.id] = profile  // Key by lift.id instead of profile.name
            }
        }

        return profiles
    }
}
