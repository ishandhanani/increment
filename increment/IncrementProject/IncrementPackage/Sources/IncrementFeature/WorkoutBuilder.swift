import Foundation

/// Dynamically builds workout templates based on workout type
/// Handles exercise selection, ordering, and configuration with built-in variability
struct WorkoutBuilder {

    /// Builds a complete workout template for the given type with exercise variability
    /// - Parameter type: The type of workout (push, pull, legs, cardio)
    /// - Returns: A fully configured WorkoutTemplate with randomly selected exercises
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

    // MARK: - Exercise Selection Logic

    /// Selects exercises from pools with built-in variability
    /// - Parameters:
    ///   - corePool: Pool of core/compound exercises
    ///   - secondaryPool: Pool of secondary compound exercises
    ///   - accessoryPool: Pool of isolation/accessory exercises
    ///   - coreCount: Number of core exercises to select
    ///   - accessoryCount: Number of accessory exercises to select
    /// - Returns: Array of selected exercises in order
    private static func selectExercises(
        from corePool: [Lift],
        secondary secondaryPool: [Lift],
        accessory accessoryPool: [Lift],
        coreCount: Int,
        accessoryCount: Int
    ) -> [Lift] {
        var selectedExercises: [Lift] = []

        // Always select main compound movements first
        let shuffledCore = corePool.shuffled()
        let coreSelections = Array(shuffledCore.prefix(coreCount))
        selectedExercises.append(contentsOf: coreSelections)

        // Mix secondary and accessory for remaining slots
        let allAccessoryOptions = secondaryPool + accessoryPool
        let shuffledAccessory = allAccessoryOptions.shuffled()
        let accessorySelections = Array(shuffledAccessory.prefix(accessoryCount))
        selectedExercises.append(contentsOf: accessorySelections)

        return selectedExercises
    }

    /// Creates a WorkoutExercise from a Lift with appropriate settings
    private static func createWorkoutExercise(
        from lift: Lift,
        order: Int,
        priority: LiftPriority,
        targetSets: Int,
        restTime: TimeInterval
    ) -> WorkoutExercise {
        return WorkoutExercise(
            lift: lift,
            order: order,
            priority: priority,
            targetSets: targetSets,
            restTime: restTime
        )
    }

    // MARK: - Push Day Builder

    private static func buildPushDay() -> WorkoutTemplate {
        // Select exercises with variability (2 core + 2 accessory)
        let selectedLifts = selectExercises(
            from: LiftLibrary.coreCompoundLifts[.push]!,
            secondary: LiftLibrary.secondaryCompoundLifts[.push]!,
            accessory: LiftLibrary.accessoryLifts[.push]!,
            coreCount: 2,
            accessoryCount: 2
        )

        var exercises: [WorkoutExercise] = []

        for (index, lift) in selectedLifts.enumerated() {
            let order = index + 1
            let isCore = index < 2 // First 2 are core

            // Configure based on exercise type
            let (priority, targetSets, restTime): (LiftPriority, Int, TimeInterval)
            if isCore {
                // Core compound movements
                priority = .core
                targetSets = 3
                restTime = TimeInterval(180)
            } else {
                // Accessory movements
                priority = .accessory
                targetSets = 3
                restTime = TimeInterval(90)
            }

            let exercise = createWorkoutExercise(
                from: lift,
                order: order,
                priority: priority,
                targetSets: targetSets,
                restTime: restTime
            )
            exercises.append(exercise)
        }

        return WorkoutTemplate(
            name: "Push Day",
            workoutType: .push,
            exercises: exercises,
            estimatedDuration: 45 * 60 // 45 minutes for 4 exercises
        )
    }

    // MARK: - Pull Day Builder

    private static func buildPullDay() -> WorkoutTemplate {
        // Select exercises with variability (2 core + 2 accessory)
        let selectedLifts = selectExercises(
            from: LiftLibrary.coreCompoundLifts[.pull]!,
            secondary: LiftLibrary.secondaryCompoundLifts[.pull]!,
            accessory: LiftLibrary.accessoryLifts[.pull]!,
            coreCount: 2,
            accessoryCount: 2
        )

        var exercises: [WorkoutExercise] = []

        for (index, lift) in selectedLifts.enumerated() {
            let order = index + 1
            let isCore = index < 2 // First 2 are core

            // Configure based on exercise type and position
            let (priority, targetSets, restTime): (LiftPriority, Int, TimeInterval)
            if isCore {
                // Core compound movements - first lift gets more rest
                let rest = index == 0 ? TimeInterval(180) : TimeInterval(150)
                priority = .core
                targetSets = 3
                restTime = rest
            } else {
                // Accessory movements
                priority = .accessory
                targetSets = 3
                restTime = TimeInterval(90)
            }

            let exercise = createWorkoutExercise(
                from: lift,
                order: order,
                priority: priority,
                targetSets: targetSets,
                restTime: restTime
            )
            exercises.append(exercise)
        }

        return WorkoutTemplate(
            name: "Pull Day",
            workoutType: .pull,
            exercises: exercises,
            estimatedDuration: 45 * 60 // 45 minutes for 4 exercises
        )
    }

    // MARK: - Leg Day Builder

    private static func buildLegDay() -> WorkoutTemplate {
        // Select exercises with variability (2 core + 2 accessory)
        let selectedLifts = selectExercises(
            from: LiftLibrary.coreCompoundLifts[.legs]!,
            secondary: LiftLibrary.secondaryCompoundLifts[.legs]!,
            accessory: LiftLibrary.accessoryLifts[.legs]!,
            coreCount: 2,
            accessoryCount: 2
        )

        var exercises: [WorkoutExercise] = []

        for (index, lift) in selectedLifts.enumerated() {
            let order = index + 1
            let isCore = index < 2 // First 2 are core

            // Configure based on exercise type and muscle group
            let (priority, targetSets, restTime): (LiftPriority, Int, TimeInterval)
            if isCore {
                // Core compound movements - squats get 4 sets, others get 3
                let sets = lift.id.contains("squat") ? 4 : 3
                let rest = index == 0 ? TimeInterval(180) : TimeInterval(150)
                priority = .core
                targetSets = sets
                restTime = rest
            } else {
                // Accessory movements - calves get more sets, shorter rest
                let sets = lift.muscleGroups.contains(.calves) ? 4 : 3
                let rest = lift.muscleGroups.contains(.calves) ? TimeInterval(60) : TimeInterval(120)
                priority = .accessory
                targetSets = sets
                restTime = rest
            }

            let exercise = createWorkoutExercise(
                from: lift,
                order: order,
                priority: priority,
                targetSets: targetSets,
                restTime: restTime
            )
            exercises.append(exercise)
        }

        return WorkoutTemplate(
            name: "Leg Day",
            workoutType: .legs,
            exercises: exercises,
            estimatedDuration: 45 * 60 // 45 minutes for 4 exercises
        )
    }

    // MARK: - Cardio Day Builder

    private static func buildCardioDay() -> WorkoutTemplate {
        // Select 1-2 cardio exercises randomly for variety
        let selectedCardio = LiftLibrary.cardioLifts.shuffled().prefix(Int.random(in: 1...2))

        var exercises: [WorkoutExercise] = []

        for (index, lift) in selectedCardio.enumerated() {
            let exercise = createWorkoutExercise(
                from: lift,
                order: index + 1,
                priority: .core,
                targetSets: 1,
                restTime: index == 0 ? 300 : 0 // 5 min rest between cardio if doing 2
            )
            exercises.append(exercise)
        }

        // Calculate duration based on selected exercises
        let totalDuration = exercises.reduce(0) { total, exercise in
            let baseDuration = if exercise.lift.id.contains("twenty") {
                20 * 60 // 20 minutes
            } else if exercise.lift.id.contains("thirty") {
                30 * 60 // 30 minutes
            } else if exercise.lift.id.contains("twenty_five") {
                25 * 60 // 25 minutes
            } else if exercise.lift.id.contains("fifteen") {
                15 * 60 // 15 minutes
            } else {
                30 * 60 // Default 30 minutes
            }
            return total + baseDuration + Int(exercise.restTime)
        }

        return WorkoutTemplate(
            name: "Cardio Day",
            workoutType: .cardio,
            exercises: exercises,
            estimatedDuration: TimeInterval(totalDuration)
        )
    }
}
