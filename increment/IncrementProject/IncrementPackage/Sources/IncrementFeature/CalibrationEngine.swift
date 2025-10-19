import Foundation

/// Computes starting weights for all exercises based on user's 1RM input
public struct CalibrationEngine {

    /// Compute exercise states from user's 1RM calibration input
    /// - Parameter input: User's 1RM for main compound lifts
    /// - Returns: CalibrationResult with exercise states for all lifts
    public static func calibrate(from input: CalibrationInput) -> CalibrationResult {
        var exerciseStates: [String: ExerciseState] = [:]

        // Get all lifts from library (built-in only for calibration)
        let allLifts = LiftLibrary.allBuiltInLifts

        for lift in allLifts {
            let startWeight = computeStartingWeight(
                for: lift,
                benchPress1RM: input.benchPress1RM,
                squat1RM: input.squat1RM,
                deadlift1RM: input.deadlift1RM
            )

            exerciseStates[lift.id] = ExerciseState(
                exerciseId: lift.id,
                lastStartLoad: startWeight,
                lastDecision: nil,
                lastUpdatedAt: Date()
            )
        }

        return CalibrationResult(exerciseStates: exerciseStates)
    }

    /// Compute starting weight for a specific lift based on user's 1RMs
    private static func computeStartingWeight(
        for lift: Lift,
        benchPress1RM: Double?,
        squat1RM: Double?,
        deadlift1RM: Double?
    ) -> Double {
        // Determine which main lift to use as reference
        let reference1RM: Double?

        switch lift.category {
        case .push:
            reference1RM = benchPress1RM
        case .legs:
            reference1RM = squat1RM ?? deadlift1RM
        case .pull:
            reference1RM = deadlift1RM
        case .cardio:
            // Cardio doesn't use 1RM - use default
            return 0.0
        }

        guard let mainLift1RM = reference1RM else {
            // No 1RM provided, use conservative defaults
            return getDefaultStartingWeight(for: lift)
        }

        // Check if this IS the main lift or an accessory
        let isMainLift = isMainCompoundLift(lift)

        if isMainLift {
            // Main compound lift - use 70% of 1RM
            return SteelProgressionEngine.calculateStartingWeight(
                from: mainLift1RM,
                rounding: lift.steelConfig.rounding
            )
        } else {
            // Accessory lift - estimate based on equipment type
            let estimated1RM = SteelProgressionEngine.estimate1RMForAccessory(
                mainLift1RM: mainLift1RM,
                equipment: lift.equipment,
                category: lift.category
            )

            return SteelProgressionEngine.calculateStartingWeight(
                from: estimated1RM,
                rounding: lift.steelConfig.rounding
            )
        }
    }

    /// Check if a lift is a main compound movement
    private static func isMainCompoundLift(_ lift: Lift) -> Bool {
        // Main compound lifts (these should match the 1RM inputs)
        let mainLifts = [
            "barbell_bench_press",
            "barbell_squat",
            "barbell_deadlift"
        ]

        return mainLifts.contains(lift.id)
    }

    /// Conservative default weights when no 1RM provided
    private static func getDefaultStartingWeight(for lift: Lift) -> Double {
        switch lift.equipment {
        case .barbell:
            // Just the bar
            return 45.0
        case .dumbbell:
            // Light dumbbells (per hand)
            return 15.0
        case .cable, .machine:
            // Moderate starting weight
            return 40.0
        case .bodyweight:
            // Not applicable
            return 0.0
        case .cardioMachine:
            // Not applicable
            return 0.0
        }
    }
}
