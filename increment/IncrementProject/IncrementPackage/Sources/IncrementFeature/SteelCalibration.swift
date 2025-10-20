import Foundation

/// Provides default calibration data for all exercises
/// These are conservative starting weights suitable for intermediate lifters
/// Users can customize via 1RM input or manual adjustment
public struct SteelCalibration {

    // MARK: - Default Starting Weights

    /// Default starting weights for common exercises (in lbs)
    /// Based on 70% of conservative 1RM estimates
    private static let defaultStartingWeights: [String: Double] = [
        // Push exercises
        "barbell_bench_press": 95.0,        // 70% of 135 lb 1RM
        "incline_dumbbell_bench": 30.0,     // 30 lb dumbbells per hand
        "cable_fly": 25.0,                  // 25 lbs per stack
        "tricep_pushdown": 30.0,            // 30 lbs
        "skullcrushers": 45.0,              // Bar only

        // Pull exercises
        "weighted_pullups": 0.0,            // Bodyweight only to start
        "lat_pulldown": 70.0,               // 70 lbs
        "barbell_row": 75.0,                // 70% of 105 lb 1RM
        "dumbbell_curl": 20.0,              // 20 lb dumbbells
        "hammer_curl": 20.0,                // 20 lb dumbbells

        // Leg exercises
        "barbell_squat": 115.0,             // 70% of 165 lb 1RM
        "weighted_lunges": 25.0,            // 25 lb dumbbells
        "leg_press": 135.0,                 // 135 lbs
        "calf_raises": 90.0,                // 90 lbs

        // Cardio (not weight-based)
        "two_mile_run": 0.0,
        "twenty_min_row": 0.0
    ]

    /// Default 1RM values for main compound lifts (intermediate level)
    private static let default1RMs: [String: Double] = [
        "barbell_bench_press": 135.0,   // One plate
        "barbell_squat": 165.0,         // Just over one plate
        "barbell_row": 105.0,           // Between bar and one plate
        "barbell_deadlift": 185.0       // Not in library yet, but standard
    ]

    // MARK: - Public API

    /// Get the default starting weight for an exercise
    /// - Parameter exerciseId: The exercise identifier (e.g., "barbell_bench_press")
    /// - Returns: Starting weight in lbs, or 45 (barbell) if not found
    public static func getDefaultStartingWeight(for exerciseId: String) -> Double {
        return defaultStartingWeights[exerciseId] ?? 45.0
    }

    /// Get the default 1RM for a main compound lift
    /// - Parameter exerciseId: The exercise identifier
    /// - Returns: 1RM in lbs, or nil if not a main compound lift
    public static func getDefault1RM(for exerciseId: String) -> Double? {
        return default1RMs[exerciseId]
    }

    /// Calculate starting weight from user-provided 1RM
    /// - Parameters:
    ///   - oneRepMax: User's tested or estimated 1RM
    ///   - equipment: Equipment type for the exercise
    ///   - config: STEEL configuration for rounding
    /// - Returns: Appropriate starting weight (70% of 1RM, rounded)
    public static func calculateStartingWeight(
        from oneRepMax: Double,
        equipment: Equipment,
        config: SteelConfig
    ) -> Double {
        let strategy = SteelProgressionStrategyFactory.strategy(for: equipment)
        return strategy.getStartingWeight(from: oneRepMax, config: config)
    }

    /// Generate initial exercise states for all exercises in a workout template
    /// Uses default starting weights or calculated weights from 1RM input
    /// - Parameters:
    ///   - template: The workout template to calibrate
    ///   - calibrationInput: Optional user-provided 1RMs for main lifts
    /// - Returns: Dictionary of exercise states ready for STEEL progression
    public static func generateInitialStates(
        for template: WorkoutTemplate,
        using calibrationInput: CalibrationInput? = nil
    ) -> [String: ExerciseState] {
        var states: [String: ExerciseState] = [:]

        for exercise in template.exercises {
            let exerciseId = exercise.lift.id
            let equipment = exercise.lift.equipment
            let config = exercise.lift.steelConfig

            // Determine starting weight
            let startWeight: Double

            // Check if user provided 1RM for this lift category
            if let input = calibrationInput {
                if exerciseId.contains("bench") || exerciseId.contains("incline"), let benchRM = input.benchPress1RM {
                    startWeight = calculateStartingWeight(from: benchRM, equipment: equipment, config: config)
                } else if exerciseId.contains("squat"), let squatRM = input.squat1RM {
                    startWeight = calculateStartingWeight(from: squatRM, equipment: equipment, config: config)
                } else if exerciseId.contains("deadlift"), let deadliftRM = input.deadlift1RM {
                    startWeight = calculateStartingWeight(from: deadliftRM, equipment: equipment, config: config)
                } else {
                    // Fall back to default
                    startWeight = getDefaultStartingWeight(for: exerciseId)
                }
            } else {
                // No calibration input, use defaults
                startWeight = getDefaultStartingWeight(for: exerciseId)
            }

            // Create exercise state
            states[exerciseId] = ExerciseState(
                exerciseId: exerciseId,
                lastStartLoad: startWeight,
                lastDecision: nil,
                lastUpdatedAt: Date()
            )
        }

        return states
    }

    // MARK: - Beginner Calibration

    /// Generate beginner-friendly calibration using conservative weights
    /// Suitable for users new to lifting or returning after time off
    /// - Parameter template: The workout template to calibrate
    /// - Returns: Dictionary of exercise states with beginner weights
    public static func generateBeginnerStates(for template: WorkoutTemplate) -> [String: ExerciseState] {
        var states: [String: ExerciseState] = [:]

        for exercise in template.exercises {
            let exerciseId = exercise.lift.id
            let equipment = exercise.lift.equipment

            // Get beginner calibration from strategy
            let strategy = SteelProgressionStrategyFactory.strategy(for: equipment)
            let beginnerWeight = strategy.getBeginnerCalibration() ?? 45.0

            states[exerciseId] = ExerciseState(
                exerciseId: exerciseId,
                lastStartLoad: beginnerWeight,
                lastDecision: nil,
                lastUpdatedAt: Date()
            )
        }

        return states
    }

    // MARK: - Accessory Exercise Estimation

    /// Estimate starting weight for accessory exercises based on main lift
    /// - Parameters:
    ///   - mainLiftId: ID of the main compound lift (e.g., "barbell_bench_press")
    ///   - mainLiftWeight: Current working weight for main lift
    ///   - accessoryExercise: The accessory exercise to estimate
    /// - Returns: Estimated starting weight for accessory
    public static func estimateAccessoryWeight(
        mainLiftId: String,
        mainLiftWeight: Double,
        accessoryExercise: Lift
    ) -> Double {
        // Estimate 1RM from working weight (inverse of 70%)
        let estimated1RM = mainLiftWeight / 0.70

        // Calculate accessory weight using strategy
        let strategy = SteelProgressionStrategyFactory.strategy(for: accessoryExercise.equipment)
        return strategy.getStartingWeight(from: estimated1RM, config: accessoryExercise.steelConfig)
    }
}
