import Foundation

// MARK: - STEEL Progression Protocol

/// Protocol defining equipment-specific STEEL progression behavior
/// Each equipment type can have unique warmup rules, increment patterns, and calibration
protocol SteelProgressionStrategy: Sendable {
    /// Equipment type this strategy handles
    var equipmentType: Equipment { get }

    /// Generate warmup prescription for this equipment type
    func generateWarmup(
        workingWeight: Double,
        priority: LiftPriority,
        exerciseIndex: Int,
        config: SteelConfig
    ) -> SteelProgressionEngine.WarmupPrescription

    /// Validate and round weight to equipment-specific increments
    func roundWeight(_ weight: Double, config: SteelConfig) -> Double

    /// Get default starting weight for calibration (70% of 1RM)
    func getStartingWeight(from oneRepMax: Double, config: SteelConfig) -> Double

    /// Get recommended initial 1RM for beginner calibration
    func getBeginnerCalibration() -> Double?
}

// MARK: - Barbell Progression

struct BarbellProgressionStrategy: SteelProgressionStrategy {
    let equipmentType: Equipment = .barbell

    func generateWarmup(
        workingWeight: Double,
        priority: LiftPriority,
        exerciseIndex: Int,
        config: SteelConfig
    ) -> SteelProgressionEngine.WarmupPrescription {
        // Accessory barbell lifts don't need warmup (already warm)
        guard priority == .core else {
            return SteelProgressionEngine.WarmupPrescription(sets: [], needsWarmup: false)
        }

        let barWeight = 45.0
        var sets: [SteelProgressionEngine.WarmupPrescription.WarmupSet] = []

        if exerciseIndex == 0 {
            // First exercise: 3 warmup sets with ramping
            // Strategy: 50% → 65% → 80% of working weight
            let percentages: [(Double, Int)] = [(0.50, 5), (0.65, 3), (0.80, 2)]

            for (index, (pct, reps)) in percentages.enumerated() {
                var weight = workingWeight * pct

                // Round to plates
                if let plates = config.plateOptions {
                    weight = SteelProgressionEngine.roundToPlates(weight, plates: plates, barWeight: barWeight)
                } else {
                    weight = (weight / 5.0).rounded() * 5.0
                }

                // Don't go below bar weight
                weight = max(barWeight, weight)

                sets.append(SteelProgressionEngine.WarmupPrescription.WarmupSet(
                    weight: weight,
                    reps: reps,
                    stepNumber: index
                ))
            }
        } else if exerciseIndex == 1 {
            // Second exercise: 1 warmup set at ~85% of working weight
            var weight = workingWeight * 0.85
            if let plates = config.plateOptions {
                weight = SteelProgressionEngine.roundToPlates(weight, plates: plates, barWeight: barWeight)
            } else {
                weight = (weight / 5.0).rounded() * 5.0
            }
            weight = max(barWeight, weight)

            sets.append(SteelProgressionEngine.WarmupPrescription.WarmupSet(
                weight: weight,
                reps: 3,
                stepNumber: 0
            ))
        }

        return SteelProgressionEngine.WarmupPrescription(sets: sets, needsWarmup: !sets.isEmpty)
    }

    func roundWeight(_ weight: Double, config: SteelConfig) -> Double {
        if let plates = config.plateOptions {
            return SteelProgressionEngine.roundToPlates(weight, plates: plates, barWeight: 45.0)
        }
        return (weight / config.rounding).rounded() * config.rounding
    }

    func getStartingWeight(from oneRepMax: Double, config: SteelConfig) -> Double {
        let startWeight = oneRepMax * 0.70
        return roundWeight(startWeight, config: config)
    }

    func getBeginnerCalibration() -> Double? {
        // Default beginner 1RMs for common barbell lifts
        // These are conservative starting points
        return 95.0  // Bar + two 25lb plates (beginner bench/row)
    }
}

// MARK: - Dumbbell Progression

struct DumbbellProgressionStrategy: SteelProgressionStrategy {
    let equipmentType: Equipment = .dumbbell

    func generateWarmup(
        workingWeight: Double,
        priority: LiftPriority,
        exerciseIndex: Int,
        config: SteelConfig
    ) -> SteelProgressionEngine.WarmupPrescription {
        // Dumbbells: Only first core exercise needs warmup
        guard priority == .core && exerciseIndex == 0 else {
            return SteelProgressionEngine.WarmupPrescription(sets: [], needsWarmup: false)
        }

        // Single warmup set at ~70% of working weight
        let warmupWeight = roundWeight(workingWeight * 0.70, config: config)

        let set = SteelProgressionEngine.WarmupPrescription.WarmupSet(
            weight: warmupWeight,
            reps: 5,
            stepNumber: 0
        )

        return SteelProgressionEngine.WarmupPrescription(sets: [set], needsWarmup: true)
    }

    func roundWeight(_ weight: Double, config: SteelConfig) -> Double {
        // Dumbbells typically available in 5lb increments
        // Round down to available dumbbell weight
        return (weight / 5.0).rounded(.down) * 5.0
    }

    func getStartingWeight(from oneRepMax: Double, config: SteelConfig) -> Double {
        // Dumbbells use ~40% of barbell 1RM per hand
        let startWeight = (oneRepMax * 0.40) * 0.70
        return roundWeight(startWeight, config: config)
    }

    func getBeginnerCalibration() -> Double? {
        return 25.0  // 25lb dumbbells (per hand)
    }
}

// MARK: - Machine Progression

struct MachineProgressionStrategy: SteelProgressionStrategy {
    let equipmentType: Equipment = .machine

    func generateWarmup(
        workingWeight: Double,
        priority: LiftPriority,
        exerciseIndex: Int,
        config: SteelConfig
    ) -> SteelProgressionEngine.WarmupPrescription {
        // Machines: Only first core exercise needs minimal warmup
        guard priority == .core && exerciseIndex == 0 else {
            return SteelProgressionEngine.WarmupPrescription(sets: [], needsWarmup: false)
        }

        // Single warmup at 60% of working weight
        let warmupWeight = roundWeight(workingWeight * 0.60, config: config)

        let set = SteelProgressionEngine.WarmupPrescription.WarmupSet(
            weight: warmupWeight,
            reps: 8,
            stepNumber: 0
        )

        return SteelProgressionEngine.WarmupPrescription(sets: [set], needsWarmup: true)
    }

    func roundWeight(_ weight: Double, config: SteelConfig) -> Double {
        // Machines vary, but typically 5-10lb increments
        return (weight / config.rounding).rounded() * config.rounding
    }

    func getStartingWeight(from oneRepMax: Double, config: SteelConfig) -> Double {
        // Machines use ~60% of barbell 1RM
        let startWeight = (oneRepMax * 0.60) * 0.70
        return roundWeight(startWeight, config: config)
    }

    func getBeginnerCalibration() -> Double? {
        return 80.0  // Typical machine starting weight
    }
}

// MARK: - Bodyweight Progression

struct BodyweightProgressionStrategy: SteelProgressionStrategy {
    let equipmentType: Equipment = .bodyweight

    func generateWarmup(
        workingWeight: Double,
        priority: LiftPriority,
        exerciseIndex: Int,
        config: SteelConfig
    ) -> SteelProgressionEngine.WarmupPrescription {
        // Bodyweight exercises don't need warmup sets
        // The exercise itself is the warmup (e.g., bodyweight pull-ups before weighted)
        return SteelProgressionEngine.WarmupPrescription(sets: [], needsWarmup: false)
    }

    func roundWeight(_ weight: Double, config: SteelConfig) -> Double {
        // For weighted bodyweight (e.g., dip belt), round to available plates
        return (weight / config.rounding).rounded() * config.rounding
    }

    func getStartingWeight(from oneRepMax: Double, config: SteelConfig) -> Double {
        // For bodyweight, starting weight is added weight (belt/vest)
        // Start with no added weight (bodyweight only)
        return 0.0
    }

    func getBeginnerCalibration() -> Double? {
        return 0.0  // Start with bodyweight only
    }
}

// MARK: - Cable Progression

struct CableProgressionStrategy: SteelProgressionStrategy {
    let equipmentType: Equipment = .cable

    func generateWarmup(
        workingWeight: Double,
        priority: LiftPriority,
        exerciseIndex: Int,
        config: SteelConfig
    ) -> SteelProgressionEngine.WarmupPrescription {
        // Cable exercises rarely need warmup (accessory work)
        guard priority == .core && exerciseIndex == 0 else {
            return SteelProgressionEngine.WarmupPrescription(sets: [], needsWarmup: false)
        }

        // If it's a core cable exercise, one light warmup
        let warmupWeight = roundWeight(workingWeight * 0.60, config: config)

        let set = SteelProgressionEngine.WarmupPrescription.WarmupSet(
            weight: warmupWeight,
            reps: 10,
            stepNumber: 0
        )

        return SteelProgressionEngine.WarmupPrescription(sets: [set], needsWarmup: true)
    }

    func roundWeight(_ weight: Double, config: SteelConfig) -> Double {
        // Cables typically in 5lb increments
        return (weight / 5.0).rounded() * 5.0
    }

    func getStartingWeight(from oneRepMax: Double, config: SteelConfig) -> Double {
        // Cables use ~50% of barbell 1RM
        let startWeight = (oneRepMax * 0.50) * 0.70
        return roundWeight(startWeight, config: config)
    }

    func getBeginnerCalibration() -> Double? {
        return 30.0  // 30lbs typical cable starting weight
    }
}

// MARK: - Cardio Progression

struct CardioProgressionStrategy: SteelProgressionStrategy {
    let equipmentType: Equipment = .cardioMachine

    func generateWarmup(
        workingWeight: Double,
        priority: LiftPriority,
        exerciseIndex: Int,
        config: SteelConfig
    ) -> SteelProgressionEngine.WarmupPrescription {
        // Cardio doesn't use warmup sets
        return SteelProgressionEngine.WarmupPrescription(sets: [], needsWarmup: false)
    }

    func roundWeight(_ weight: Double, config: SteelConfig) -> Double {
        // Cardio doesn't use weight
        return 0.0
    }

    func getStartingWeight(from oneRepMax: Double, config: SteelConfig) -> Double {
        // Cardio doesn't use weight-based progression
        return 0.0
    }

    func getBeginnerCalibration() -> Double? {
        return nil  // Not applicable
    }
}

// MARK: - Strategy Factory

/// Factory for creating equipment-specific progression strategies
struct SteelProgressionStrategyFactory: Sendable {
    private static let strategies: [Equipment: any SteelProgressionStrategy] = [
        .barbell: BarbellProgressionStrategy(),
        .dumbbell: DumbbellProgressionStrategy(),
        .machine: MachineProgressionStrategy(),
        .bodyweight: BodyweightProgressionStrategy(),
        .cable: CableProgressionStrategy(),
        .cardioMachine: CardioProgressionStrategy()
    ]

    /// Get the appropriate progression strategy for the given equipment
    static func strategy(for equipment: Equipment) -> SteelProgressionStrategy {
        return strategies[equipment] ?? BarbellProgressionStrategy()
    }
}
