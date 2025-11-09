import Foundation

/// S.T.E.E.L.™ Progression Engine (Simplified)
/// Core lifts: 3x8, Accessory lifts: 4x10-12
/// Weight changes: 5lb per side only
public class SteelProgressionEngine {

    // MARK: - Warmup Prescription

    /// Result of warmup calculation
    public struct WarmupPrescription {
        public let sets: [WarmupSet]
        public let needsWarmup: Bool

        public struct WarmupSet {
            public let weight: Double
            public let reps: Int
            public let stepNumber: Int  // 0-indexed
        }
    }

    /// Determines if an exercise needs warmup and generates warmup sets
    /// - Parameters:
    ///   - equipment: Type of equipment used
    ///   - workingWeight: Starting weight for working sets
    ///   - category: Exercise category (cardio, etc.)
    ///   - priority: Exercise priority (.core or .accessory)
    ///   - exerciseIndex: Position in workout (0 = first exercise, 1 = second, etc.)
    ///   - config: STEEL configuration for the exercise
    /// - Returns: Warmup prescription with sets or indication that no warmup needed
    public static func prescribeWarmup(
        equipment: Equipment,
        workingWeight: Double,
        category: LiftCategory,
        priority: LiftPriority,
        exerciseIndex: Int,
        config: SteelConfig
    ) -> WarmupPrescription {
        // Delegate to equipment-specific strategy
        let strategy = SteelProgressionStrategyFactory.strategy(for: equipment)
        return strategy.generateWarmup(
            workingWeight: workingWeight,
            priority: priority,
            exerciseIndex: exerciseIndex,
            config: config
        )
    }

    // MARK: - End-of-Exercise Decision (Simplified)

    /// Computes session decision based on all set logs
    /// Simple rules:
    /// - All EASY → add weight
    /// - Any FAIL/HOLY_SHIT → reduce weight
    /// - Otherwise → hold
    public static func computeDecision(
        setLogs: [SetLog],
        repRange: ClosedRange<Int>,
        totalSets: Int
    ) -> SessionDecision {
        // Count ratings
        let easyCount = setLogs.filter { $0.rating == .easy }.count
        let hardCount = setLogs.filter { $0.rating == .hard }.count
        let struggledCount = setLogs.filter { $0.rating == .holyShit || $0.rating == .fail }.count

        // Simple decision logic
        if struggledCount > 0 {
            // Any failure or major struggle → reduce weight
            return .down_1
        } else if easyCount == totalSets {
            // All sets felt easy → add weight
            return .up_1
        } else {
            // Mix of easy and hard, or all hard → maintain weight
            return .hold
        }
    }

    // MARK: - Next-Session Start Weight (Simplified)

    public struct NextSessionResult {
        public let startWeight: Double
        public let reason: String
    }

    /// Computes next session's start weight
    /// Simple rules:
    /// - up_1: add 5lb per side (10lb for barbell, 5lb for dumbbell)
    /// - down_1: subtract 5lb per side
    /// - hold: maintain weight
    public static func computeNextSessionWeight(
        lastStartLoad: Double,
        decision: SessionDecision,
        incrementPerSide: Double,
        equipment: Equipment,
        plateOptions: [Double]?
    ) -> NextSessionResult {
        var nextWeight = lastStartLoad
        var reason = ""

        // Calculate total increment based on equipment
        let totalIncrement: Double
        switch equipment {
        case .barbell:
            // 5lb per side = 10lb total
            totalIncrement = incrementPerSide * 2
        case .dumbbell:
            // 5lb per dumbbell
            totalIncrement = incrementPerSide
        case .cable, .machine, .bodyweight, .cardioMachine:
            // 5lb total
            totalIncrement = incrementPerSide
        }

        // Apply decision
        switch decision {
        case .up_2:
            // Not used in simplified version, treat as up_1
            nextWeight += totalIncrement
            reason = "All sets felt easy"
        case .up_1:
            nextWeight += totalIncrement
            reason = "All sets felt easy"
        case .down_1:
            nextWeight -= totalIncrement
            reason = "Struggled on one or more sets"
        case .hold:
            reason = "Maintaining current load"
        }

        // Round to 5lb increments for all equipment
        nextWeight = round(nextWeight, to: 5.0)

        // Plate math for barbells (ensure achievable with available plates)
        if equipment == .barbell, let plates = plateOptions {
            nextWeight = roundToPlates(nextWeight, plates: plates, barWeight: 45.0)
        }

        // Floor at 0 or minimum weight
        nextWeight = max(equipment == .barbell ? 45.0 : 0.0, nextWeight)

        return NextSessionResult(startWeight: nextWeight, reason: reason)
    }

    // MARK: - Plate Math

    /// Rounds weight to achievable value with available plates
    public static func roundToPlates(_ targetWeight: Double, plates: [Double], barWeight: Double) -> Double {
        let perSide = (targetWeight - barWeight) / 2.0
        guard perSide > 0 else { return barWeight }

        let sortedPlates = plates.sorted(by: >)
        var remaining = perSide
        var usedPlates: [Double] = []

        for plate in sortedPlates {
            while remaining >= plate {
                usedPlates.append(plate)
                remaining -= plate
            }
        }

        let achievablePerSide = usedPlates.reduce(0, +)
        return barWeight + (achievablePerSide * 2)
    }

    /// Computes per-side plate breakdown
    public static func computePlateBreakdown(_ targetWeight: Double, plates: [Double], barWeight: Double) -> [Double] {
        let perSide = (targetWeight - barWeight) / 2.0
        guard perSide > 0 else { return [] }

        let sortedPlates = plates.sorted(by: >)
        var remaining = perSide
        var usedPlates: [Double] = []

        for plate in sortedPlates {
            while remaining >= plate {
                usedPlates.append(plate)
                remaining -= plate
            }
        }

        return usedPlates.sorted(by: >)
    }

    // MARK: - Helper Functions

    private static func round(_ value: Double, to rounding: Double) -> Double {
        return (value / rounding).rounded() * rounding
    }

    // MARK: - 1RM Calibration

    /// Calculates starting weight for an exercise based on 1RM
    /// Uses 70% of 1RM as starting point for optimal progression
    /// - Parameters:
    ///   - oneRepMax: User's estimated or tested 1RM
    /// - Returns: Starting weight rounded to 5lb
    public static func calculateStartingWeight(from oneRepMax: Double) -> Double {
        let startingWeight = oneRepMax * 0.70
        return round(startingWeight, to: 5.0)
    }

    /// Estimates 1RM for accessory/isolation exercises based on main lift 1RM
    /// - Parameters:
    ///   - mainLift1RM: 1RM of the main compound lift (e.g., bench press)
    ///   - equipment: Equipment type for the accessory exercise
    ///   - category: Lift category (push/pull/legs)
    /// - Returns: Estimated 1RM for the accessory exercise
    public static func estimate1RMForAccessory(
        mainLift1RM: Double,
        equipment: Equipment,
        category: LiftCategory
    ) -> Double {
        // Accessory movements typically use 40-60% of main lift weight
        let ratio: Double

        switch equipment {
        case .barbell:
            // Secondary barbell movements (e.g., incline bench from flat bench)
            ratio = 0.75
        case .dumbbell:
            // Dumbbells are roughly 40% of barbell per hand (80% total for pair)
            ratio = 0.40  // Per dumbbell
        case .cable:
            // Cable isolation work
            ratio = 0.50
        case .machine:
            // Machine work
            ratio = 0.60
        case .bodyweight, .cardioMachine:
            // Not applicable for 1RM estimation
            ratio = 0.0
        }

        return mainLift1RM * ratio
    }
}
