import Foundation

/// S.T.E.E.L.™ Progression Engine
/// Set-to-set Tuning + End-of-exercise Escalation/Lowering
class SteelProgressionEngine {

    // MARK: - Within-Session Micro-Adjust (4B)

    struct MicroAdjustResult {
        let nextWeight: Double
        let nextReps: Int
    }

    /// Computes next set prescription based on current performance
    static func microAdjust(
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
    static func shouldActivateBadDaySwitch(setLogs: [SetLog]) -> Bool {
        guard setLogs.count >= 2 else { return false }
        let firstTwo = Array(setLogs.prefix(2))
        return firstTwo.allSatisfy { $0.rating == .fail || $0.rating == .holyShit }
    }

    /// Apply bad-day adjustment (drop by base increment, target min reps)
    static func applyBadDayAdjustment(
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
    static func computeDecision(
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

    struct NextSessionResult {
        let startWeight: Double
        let reason: String
    }

    /// Computes next session's start weight with rounding, weekly cap, and plate math
    static func computeNextSessionWeight(
        lastStartLoad: Double,
        decision: SessionDecision,
        baseIncrement: Double,
        rounding: Double,
        weeklyCapPct: Double,
        recentLoads: [Double],  // Loads from last 7 days
        plateOptions: [Double]?
    ) -> NextSessionResult {
        var W0 = lastStartLoad

        // Apply decision
        switch decision {
        case .up_2:
            W0 += 2 * baseIncrement
        case .up_1:
            W0 += baseIncrement
        case .down_1:
            W0 -= baseIncrement
        case .hold:
            break
        }

        // Round
        W0 = round(W0, to: rounding)

        // Weekly cap check
        let weeklyIncrease = W0 - (recentLoads.min() ?? lastStartLoad)
        let maxAllowedIncrease = lastStartLoad * (weeklyCapPct / 100.0)

        var reason = decisionReason(decision)

        if weeklyIncrease > maxAllowedIncrease {
            W0 = lastStartLoad + maxAllowedIncrease
            W0 = round(W0, to: rounding)
            reason = "Weekly cap applied"
        }

        // Plate math for barbells
        if let plates = plateOptions {
            W0 = roundToPlates(W0, plates: plates, barWeight: 45.0)
        }

        // Floor at 0
        W0 = max(0, W0)

        return NextSessionResult(startWeight: W0, reason: reason)
    }

    // MARK: - Plate Math

    /// Rounds weight to achievable value with available plates
    static func roundToPlates(_ targetWeight: Double, plates: [Double], barWeight: Double) -> Double {
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
    static func computePlateBreakdown(_ targetWeight: Double, plates: [Double], barWeight: Double) -> [Double] {
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