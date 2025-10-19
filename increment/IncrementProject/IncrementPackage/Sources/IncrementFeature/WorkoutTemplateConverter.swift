import Foundation

/// Utilities to convert between new workout models and existing STEEL models
struct WorkoutTemplateConverter {

    /// Converts a Lift to an ExerciseProfile (maintaining STEEL compatibility)
    static func toExerciseProfile(from lift: Lift, sets: Int, restSec: Int) -> ExerciseProfile {
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
            repRange: lift.steelConfig.repRange,
            sets: sets,
            baseIncrement: lift.steelConfig.baseIncrement,
            rounding: lift.steelConfig.rounding,
            microAdjustStep: lift.steelConfig.microAdjustStep,
            weeklyCapPct: lift.steelConfig.weeklyCapPct,
            plateOptions: lift.steelConfig.plateOptions,
            warmupRule: lift.steelConfig.warmupRule,
            defaultRestSec: restSec
        )
    }

    /// Converts a WorkoutTemplate to a WorkoutPlan and dictionary of ExerciseProfiles
    /// Returns: (WorkoutPlan, [UUID: ExerciseProfile])
    static func toWorkoutPlan(from template: WorkoutTemplate) -> (WorkoutPlan, [UUID: ExerciseProfile]) {
        var profiles: [UUID: ExerciseProfile] = [:]
        var exerciseIds: [UUID] = []

        // Convert each WorkoutExercise to an ExerciseProfile
        for workoutExercise in template.exercises.sorted(by: { $0.order < $1.order }) {
            let profile = toExerciseProfile(
                from: workoutExercise.lift,
                sets: workoutExercise.targetSets,
                restSec: Int(workoutExercise.restTime)
            )
            profiles[profile.id] = profile
            exerciseIds.append(profile.id)
        }

        // Create WorkoutPlan with same ID as template for consistency
        let plan = WorkoutPlan(
            id: template.id,
            name: template.name,
            order: exerciseIds
        )

        return (plan, profiles)
    }
}
