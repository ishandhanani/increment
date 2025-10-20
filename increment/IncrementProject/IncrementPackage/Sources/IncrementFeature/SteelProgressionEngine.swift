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
    ///   - plateOptions: Available plates for proper warmup progression (barbells only)
    /// - Returns: Warmup prescription with sets or indication that no warmup needed
    public static func prescribeWarmup(
        equipment: Equipment,
        workingWeight: Double,
        category: LiftCategory,
        plateOptions: [Double]? = nil
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

        // Barbell exercises: Use plate-aware progression
        if equipment == .barbell {
            sets = generateBarbellWarmup(workingWeight: workingWeight, plateOptions: plateOptions)
        }
        // Dumbbell/Machine: 1-2 warmup sets based on working weight
        else if equipment == .dumbbell || equipment == .machine {
            if workingWeight >= 50 {
                // Heavier weight: 2 warmups
                sets = [
                    WarmupPrescription.WarmupSet(weight: workingWeight * 0.6, reps: 5, stepNumber: 0),
                    WarmupPrescription.WarmupSet(weight: workingWeight * 0.8, reps: 3, stepNumber: 1)
                ]
            } else {
                // Lighter weight: 1 warmup
                sets = [
                    WarmupPrescription.WarmupSet(weight: workingWeight * 0.7, reps: 5, stepNumber: 0)
                ]
            }
        }
        // Cable: 1-2 moderate warmups
        else if equipment == .cable {
            if workingWeight >= 60 {
                sets = [
                    WarmupPrescription.WarmupSet(weight: workingWeight * 0.6, reps: 5, stepNumber: 0),
                    WarmupPrescription.WarmupSet(weight: workingWeight * 0.8, reps: 3, stepNumber: 1)
                ]
            } else {
                sets = [
                    WarmupPrescription.WarmupSet(weight: workingWeight * 0.7, reps: 5, stepNumber: 0)
                ]
            }
        }

        return WarmupPrescription(sets: sets, needsWarmup: !sets.isEmpty)
    }

    /// Generates optimal barbell warmup progression using real plate combinations
    /// Follows standard gym plate loading: 45 → 95 → 115 → 135 → 155 → 185 → 205 → 225 → etc.
    private static func generateBarbellWarmup(
        workingWeight: Double,
        plateOptions: [Double]?
    ) -> [WarmupPrescription.WarmupSet] {
        let barWeight = 45.0
        var sets: [WarmupPrescription.WarmupSet] = []

        // For very light working weights (<= 65 lbs), just use the bar
        if workingWeight <= 65 {
            sets.append(WarmupPrescription.WarmupSet(weight: barWeight, reps: 5, stepNumber: 0))
            return sets
        }

        // Standard plate progression (commonly loaded weights)
        // These represent typical gym warmup patterns
        let standardWeights: [Double] = [45, 95, 115, 135, 155, 185, 205, 225, 275, 315, 365, 405, 455]

        // Find warmup weights that are below working weight
        var warmupWeights: [Double] = []

        for weight in standardWeights {
            if weight < workingWeight {
                warmupWeights.append(weight)
            } else {
                break
            }
        }

        // If working weight doesn't align with standard weights, add a final warmup at ~85-90%
        let finalWarmupTarget = workingWeight * 0.87 // ~87% of working weight
        if let lastWarmup = warmupWeights.last, lastWarmup < finalWarmupTarget {
            // Add one more warmup closer to working weight
            if let plates = plateOptions {
                let closerWarmup = roundToPlates(finalWarmupTarget, plates: plates, barWeight: barWeight)
                if closerWarmup > lastWarmup && closerWarmup < workingWeight {
                    warmupWeights.append(closerWarmup)
                }
            } else {
                // No plates specified, use percentage-based
                warmupWeights.append(finalWarmupTarget)
            }
        }

        // Determine rep scheme based on weight percentage
        // Strategy: Start with higher reps (5), decrease as weight increases (3, 2, 1)
        for (index, weight) in warmupWeights.enumerated() {
            let reps: Int
            let percentOfWorkingWeight = weight / workingWeight

            if percentOfWorkingWeight < 0.5 {
                reps = 5  // Light warmup: 5 reps
            } else if percentOfWorkingWeight < 0.75 {
                reps = 3  // Moderate warmup: 3 reps
            } else if percentOfWorkingWeight < 0.9 {
                reps = 2  // Heavy warmup: 2 reps
            } else {
                reps = 1  // Very heavy warmup: 1 rep
            }

            sets.append(WarmupPrescription.WarmupSet(
                weight: weight,
                reps: reps,
                stepNumber: index
            ))
        }

        // Ensure we have at least 1 warmup set but not more than 5
        if sets.isEmpty {
            // Fallback: simple percentage-based warmup
            sets.append(WarmupPrescription.WarmupSet(weight: workingWeight * 0.7, reps: 5, stepNumber: 0))
        } else if sets.count > 5 {
            // Too many warmups - keep only the most relevant ones
            // Keep first, last, and middle warmups
            let keep = [0, sets.count / 3, 2 * sets.count / 3, sets.count - 1]
            sets = keep.enumerated().map { index, originalIndex in
                let originalSet = sets[originalIndex]
                return WarmupPrescription.WarmupSet(
                    weight: originalSet.weight,
                    reps: originalSet.reps,
                    stepNumber: index
                )
            }
        }

        return sets
    }

    // MARK: - Within-Session Micro-Adjust (4B)

    public struct MicroAdjustResult {
        public let nextWeight: Double
        public let nextReps: Int
    }

    /// Computes next set prescription based on current performance
    /// Adjusted for real-world training patterns with smarter progression/regression
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
            // Complete failure - significant weight reduction
            // Drop by full base increment to ensure recovery
            let nextWeight = round(max(0, currentWeight - baseIncrement), to: rounding)
            return MicroAdjustResult(nextWeight: nextWeight, nextReps: rMin)

        case .holyShit:
            // Struggled badly - conservative approach
            if achievedReps < rMin {
                // Didn't even hit minimum - drop weight significantly
                let nextWeight = round(max(0, currentWeight - baseIncrement), to: rounding)
                return MicroAdjustResult(nextWeight: nextWeight, nextReps: rMin)
            } else if achievedReps <= rMin + 1 {
                // Just barely hit minimum - drop by micro if available
                if micro > 0 {
                    let nextWeight = round(max(0, currentWeight - micro), to: rounding)
                    return MicroAdjustResult(nextWeight: nextWeight, nextReps: rMin)
                }
            }
            // Hit reps but it was very hard - maintain weight
            return MicroAdjustResult(nextWeight: currentWeight, nextReps: clamp(achievedReps, rMin, rMax))

        case .hard:
            // Challenging but doable - maintain or small adjustment
            if achievedReps < rMin {
                // Didn't hit minimum - drop by micro if available, else base
                let dropAmount = micro > 0 ? micro : baseIncrement
                let nextWeight = round(max(0, currentWeight - dropAmount), to: rounding)
                return MicroAdjustResult(nextWeight: nextWeight, nextReps: rMin)
            } else if achievedReps == rMin {
                // Hit exactly minimum - maintain weight, stay at minimum reps
                return MicroAdjustResult(nextWeight: currentWeight, nextReps: rMin)
            } else {
                // Hit above minimum - maintain weight, aim for same reps achieved
                return MicroAdjustResult(nextWeight: currentWeight, nextReps: clamp(achievedReps, rMin, rMax))
            }

        case .easy:
            // Felt easy - add weight if hitting upper range
            if achievedReps >= rMax {
                // Hit top of range and felt easy - add micro load if available
                if micro > 0 {
                    let nextWeight = round(currentWeight + micro, to: rounding)
                    return MicroAdjustResult(nextWeight: nextWeight, nextReps: rMax)
                } else {
                    // No micro available - maintain weight, aim for more reps next time
                    return MicroAdjustResult(nextWeight: currentWeight, nextReps: rMax)
                }
            } else if achievedReps >= rMax - 1 {
                // Close to top - maintain weight, push for max reps
                return MicroAdjustResult(nextWeight: currentWeight, nextReps: rMax)
            } else {
                // Mid-range - maintain weight, aim for achieved reps
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

    // MARK: - 1RM Calibration

    /// Calculates starting weight for an exercise based on 1RM
    /// Uses 70% of 1RM as starting point for optimal progression
    /// - Parameters:
    ///   - oneRepMax: User's estimated or tested 1RM
    ///   - rounding: Rounding increment from exercise profile
    /// - Returns: Starting weight rounded appropriately
    public static func calculateStartingWeight(
        from oneRepMax: Double,
        rounding: Double
    ) -> Double {
        let startingWeight = oneRepMax * 0.70
        return round(startingWeight, to: rounding)
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