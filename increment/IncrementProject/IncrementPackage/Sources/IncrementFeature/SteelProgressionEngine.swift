import Foundation

/// S.T.E.E.L.™ Progression Engine
/// Set-to-set Tuning + End-of-exercise Escalation/Lowering
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
    /// - Returns: Warmup prescription with sets or indication that no warmup needed
    public static func prescribeWarmup(
        equipment: Equipment,
        workingWeight: Double,
        category: LiftCategory
    ) -> WarmupPrescription {
        // Skip warmups for cardio
        if equipment == .cardioMachine || category == .cardio {
            return WarmupPrescription(sets: [], needsWarmup: false)
        }

        // Skip warmups for bodyweight exercises
        if equipment == .bodyweight {
            return WarmupPrescription(sets: [], needsWarmup: false)
        }

        // Generate warmup sets based on equipment and weight
        var sets: [WarmupPrescription.WarmupSet] = []

        // Heavy barbell (>225 lbs): 3 warmup sets
        if equipment == .barbell && workingWeight > 225 {
            sets = [
                WarmupPrescription.WarmupSet(weight: workingWeight * 0.4, reps: 5, stepNumber: 0),
                WarmupPrescription.WarmupSet(weight: workingWeight * 0.6, reps: 4, stepNumber: 1),
                WarmupPrescription.WarmupSet(weight: workingWeight * 0.8, reps: 2, stepNumber: 2)
            ]
        }
        // Dumbbell/Machine: 1 lighter warmup
        else if equipment == .dumbbell || equipment == .machine {
            sets = [
                WarmupPrescription.WarmupSet(weight: workingWeight * 0.7, reps: 5, stepNumber: 0)
            ]
        }
        // Standard barbell: 2 warmup sets
        else if equipment == .barbell {
            sets = [
                WarmupPrescription.WarmupSet(weight: workingWeight * 0.5, reps: 5, stepNumber: 0),
                WarmupPrescription.WarmupSet(weight: workingWeight * 0.7, reps: 3, stepNumber: 1)
            ]
        }
        // Cable: 1 moderate warmup
        else if equipment == .cable {
            sets = [
                WarmupPrescription.WarmupSet(weight: workingWeight * 0.6, reps: 5, stepNumber: 0)
            ]
        }

        return WarmupPrescription(sets: sets, needsWarmup: !sets.isEmpty)
    }

    // MARK: - Within-Session Micro-Adjust (4B)

    public struct MicroAdjustResult {
        public let nextWeight: Double
        public let nextReps: Int
    }

    /// Computes next set prescription based on current performance
    public static func microAdjust(
        currentWeight: Double,
        achievedReps: Int,
        repRange: ClosedRange<Int>,
        rating: Rating,
        baseIncrement: Double,
        microAdjustStep: Double?,
        rounding: Double
    ) -> MicroAdjustResult {
        let rMin = repRange.lowerBound
        let rMax = repRange.upperBound
        let micro = microAdjustStep ?? 0

        switch rating {
        case .fail:
            // Drop by base increment, target min reps
            let nextWeight = round(max(0, currentWeight - baseIncrement), to: rounding)
            return MicroAdjustResult(nextWeight: nextWeight, nextReps: rMin)

        case .holyShit:
            // If below min reps, drop weight; else hold
            if achievedReps < rMin {
                let nextWeight = round(max(0, currentWeight - baseIncrement), to: rounding)
                return MicroAdjustResult(nextWeight: nextWeight, nextReps: rMin)
            } else {
                return MicroAdjustResult(nextWeight: currentWeight, nextReps: clamp(achievedReps, rMin, rMax))
            }

        case .hard:
            // If below min and micro exists, drop by micro; else hold
            if achievedReps < rMin && micro > 0 {
                let nextWeight = round(max(0, currentWeight - micro), to: rounding)
                return MicroAdjustResult(nextWeight: nextWeight, nextReps: rMin)
            } else {
                return MicroAdjustResult(nextWeight: currentWeight, nextReps: clamp(achievedReps, rMin, rMax))
            }

        case .easy:
            // If at/above max and micro exists, add micro; else hold
            if achievedReps >= rMax && micro > 0 {
                let nextWeight = round(currentWeight + micro, to: rounding)
                return MicroAdjustResult(nextWeight: nextWeight, nextReps: rMax)
            } else {
                return MicroAdjustResult(nextWeight: currentWeight, nextReps: clamp(achievedReps, rMin, rMax))
            }
        }
    }

    /// Bad-Day Switch: Check if first two working sets are red
    public static func shouldActivateBadDaySwitch(setLogs: [SetLog]) -> Bool {
        guard setLogs.count >= 2 else { return false }
        let firstTwo = Array(setLogs.prefix(2))
        return firstTwo.allSatisfy { $0.rating == .fail || $0.rating == .holyShit }
    }

    /// Apply bad-day adjustment (drop by base increment, target min reps)
    public static func applyBadDayAdjustment(
        currentWeight: Double,
        baseIncrement: Double,
        rounding: Double,
        repRange: ClosedRange<Int>
    ) -> MicroAdjustResult {
        let nextWeight = round(max(0, currentWeight - baseIncrement), to: rounding)
        return MicroAdjustResult(nextWeight: nextWeight, nextReps: repRange.lowerBound)
    }

    // MARK: - End-of-Exercise Decision (4C)

    /// Computes session decision based on all set logs
    public static func computeDecision(
        setLogs: [SetLog],
        repRange: ClosedRange<Int>,
        totalSets: Int
    ) -> SessionDecision {
        let rMin = repRange.lowerBound
        let rMax = repRange.upperBound

        // Counters
        let S_red = setLogs.filter { $0.rating == .holyShit || $0.rating == .fail }.count
        let S_hit_top = setLogs.filter { $0.achievedReps >= rMax && $0.rating != .holyShit }.count
        let S_meet = setLogs.filter { $0.achievedReps >= rMin && $0.rating != .fail }.count
        let S_easyTop = setLogs.filter { $0.achievedReps >= rMax && $0.rating == .easy }.count

        // All sets at max reps?
        let allAtMax = setLogs.allSatisfy { $0.achievedReps >= rMax }

        // Decision logic
        if allAtMax && S_easyTop >= totalSets / 2 {
            return .up_2
        } else if S_meet == totalSets && S_red == 0 && S_hit_top >= totalSets - 1 {
            return .up_1
        } else if S_red >= 2 || S_meet < totalSets - 1 {
            return .down_1
        } else {
            return .hold
        }
    }

    // MARK: - Next-Session Start Weight (4D)

    public struct NextSessionResult {
        public let startWeight: Double
        public let reason: String
    }

    /// Computes next session's start weight with rounding, weekly cap, and plate math
    public static func computeNextSessionWeight(
        lastStartLoad: Double,
        decision: SessionDecision,
        config: SteelConfig,
        recentLoads: [Double]  // Loads from last 7 days
    ) -> NextSessionResult {
        var W0 = lastStartLoad

        // Apply decision
        switch decision {
        case .up_2:
            W0 += 2 * config.baseIncrement
        case .up_1:
            W0 += config.baseIncrement
        case .down_1:
            W0 -= config.baseIncrement
        case .hold:
            break
        }

        // Round
        W0 = round(W0, to: config.rounding)

        // Weekly cap check
        let weeklyIncrease = W0 - (recentLoads.min() ?? lastStartLoad)
        let maxAllowedIncrease = lastStartLoad * (config.weeklyCapPct / 100.0)

        var reason = decisionReason(decision)

        if weeklyIncrease > maxAllowedIncrease {
            W0 = lastStartLoad + maxAllowedIncrease
            W0 = round(W0, to: config.rounding)
            reason = "Weekly cap applied"
        }

        // Plate math for barbells
        if let plates = config.plateOptions {
            W0 = roundToPlates(W0, plates: plates, barWeight: 45.0)
        }

        // Floor at 0
        W0 = max(0, W0)

        return NextSessionResult(startWeight: W0, reason: reason)
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

    private static func clamp(_ value: Int, _ min: Int, _ max: Int) -> Int {
        return Swift.min(Swift.max(value, min), max)
    }

    private static func decisionReason(_ decision: SessionDecision) -> String {
        switch decision {
        case .up_2:
            return "All sets at top range, felt easy"
        case .up_1:
            return "Hit targets, no failures"
        case .down_1:
            return "Multiple red sets or missed targets"
        case .hold:
            return "Maintaining current load"
        }
    }
}