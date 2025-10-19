import Foundation

/// Dynamically builds workout templates based on workout type
/// Handles exercise selection, ordering, and configuration
struct WorkoutBuilder {

    /// Builds a complete workout template for the given type
    /// - Parameter type: The type of workout (push, pull, legs, cardio)
    /// - Returns: A fully configured WorkoutTemplate
    static func build(type: LiftCategory) -> WorkoutTemplate {
        switch type {
        case .push:
            return buildPushDay()
        case .pull:
            return buildPullDay()
        case .legs:
            return buildLegDay()
        case .cardio:
            return buildCardioDay()
        }
    }

    // MARK: - Push Day Builder

    private static func buildPushDay() -> WorkoutTemplate {
        let exercises: [WorkoutExercise] = [
            // Core lifts (2)
            WorkoutExercise(
                lift: LiftLibrary.benchPress,
                order: 1,
                priority: .core,
                targetSets: 3,
                restTime: 180
            ),
            WorkoutExercise(
                lift: LiftLibrary.inclineDumbbellBench,
                order: 2,
                priority: .core,
                targetSets: 3,
                restTime: 150
            ),
            // Accessory lifts (3)
            WorkoutExercise(
                lift: LiftLibrary.cableFly,
                order: 3,
                priority: .accessory,
                targetSets: 3,
                restTime: 90
            ),
            WorkoutExercise(
                lift: LiftLibrary.tricepPushdown,
                order: 4,
                priority: .accessory,
                targetSets: 3,
                restTime: 90
            ),
            WorkoutExercise(
                lift: LiftLibrary.skullcrushers,
                order: 5,
                priority: .accessory,
                targetSets: 3,
                restTime: 90
            )
        ]

        return WorkoutTemplate(
            name: "Push Day",
            workoutType: .push,
            exercises: exercises,
            estimatedDuration: 60 * 60
        )
    }

    // MARK: - Pull Day Builder

    private static func buildPullDay() -> WorkoutTemplate {
        let exercises: [WorkoutExercise] = [
            // Core lifts (3)
            WorkoutExercise(
                lift: LiftLibrary.pullups,
                order: 1,
                priority: .core,
                targetSets: 3,
                restTime: 180
            ),
            WorkoutExercise(
                lift: LiftLibrary.latPulldown,
                order: 2,
                priority: .core,
                targetSets: 3,
                restTime: 150
            ),
            WorkoutExercise(
                lift: LiftLibrary.barbellRow,
                order: 3,
                priority: .core,
                targetSets: 3,
                restTime: 150
            ),
            // Accessory lifts (2)
            WorkoutExercise(
                lift: LiftLibrary.dumbbellCurl,
                order: 4,
                priority: .accessory,
                targetSets: 3,
                restTime: 90
            ),
            WorkoutExercise(
                lift: LiftLibrary.hammerCurl,
                order: 5,
                priority: .accessory,
                targetSets: 3,
                restTime: 90
            )
        ]

        return WorkoutTemplate(
            name: "Pull Day",
            workoutType: .pull,
            exercises: exercises,
            estimatedDuration: 60 * 60
        )
    }

    // MARK: - Leg Day Builder

    private static func buildLegDay() -> WorkoutTemplate {
        let exercises: [WorkoutExercise] = [
            // Core lifts (2)
            WorkoutExercise(
                lift: LiftLibrary.squat,
                order: 1,
                priority: .core,
                targetSets: 4,
                restTime: 180
            ),
            WorkoutExercise(
                lift: LiftLibrary.weightedLunges,
                order: 2,
                priority: .core,
                targetSets: 3,
                restTime: 150
            ),
            // Accessory lifts (2)
            WorkoutExercise(
                lift: LiftLibrary.legPress,
                order: 3,
                priority: .accessory,
                targetSets: 3,
                restTime: 120
            ),
            WorkoutExercise(
                lift: LiftLibrary.calfRaises,
                order: 4,
                priority: .accessory,
                targetSets: 4,
                restTime: 60
            )
        ]

        return WorkoutTemplate(
            name: "Leg Day",
            workoutType: .legs,
            exercises: exercises,
            estimatedDuration: 60 * 60
        )
    }

    // MARK: - Cardio Day Builder

    private static func buildCardioDay() -> WorkoutTemplate {
        let exercises: [WorkoutExercise] = [
            WorkoutExercise(
                lift: LiftLibrary.run,
                order: 1,
                priority: .core,
                targetSets: 1,
                restTime: 0
            )
        ]

        return WorkoutTemplate(
            name: "Cardio Day",
            workoutType: .cardio,
            exercises: exercises,
            estimatedDuration: 30 * 60
        )
    }
}
