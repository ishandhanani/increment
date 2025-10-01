import Testing
@testable import IncrementFeature

/*
 * SteelProgressionEngineTests
 *
 * Tests the core S.T.E.E.L. progression algorithm that determines:
 * - Set-to-set weight/rep adjustments based on performance ratings
 * - Bad-day detection when consecutive sets fail
 * - End-of-exercise decisions (increase, hold, or decrease weight)
 * - Next session starting weights with weekly caps
 * - Plate math for barbell exercises
 *
 * These tests ensure users progress safely and effectively without getting
 * injured from excessive weight increases or stalling from too-conservative programming.
 */

@Suite("SteelProgressionEngine Tests")
struct SteelProgressionEngineTests {

    // MARK: - Micro-Adjust Tests (Set-to-Set Adjustments)

    /// Test that a FAIL rating drops weight by base increment
    /// Critical: Ensures users reduce weight when they can't complete reps safely
    @Test("Micro-adjust: FAIL rating drops weight")
    func testMicroAdjustFail() {
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: 100.0,
            achievedReps: 3,
            repRange: 5...8,
            rating: .fail,
            baseIncrement: 5.0,
            microAdjustStep: 2.5,
            rounding: 2.5
        )

        #expect(result.nextWeight == 95.0)
        #expect(result.nextReps == 5)
    }

    /// Test that HOLY_SHIT rating holds weight when reps are in range
    /// Critical: Prevents dropping weight when user hits target despite difficulty
    @Test("Micro-adjust: HOLY_SHIT at min reps holds weight")
    func testMicroAdjustHolyShitAtMin() {
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: 100.0,
            achievedReps: 5,
            repRange: 5...8,
            rating: .holyShit,
            baseIncrement: 5.0,
            microAdjustStep: 2.5,
            rounding: 2.5
        )

        #expect(result.nextWeight == 100.0)
        #expect(result.nextReps == 5)
    }

    /// Test that HARD rating with below-min reps drops by micro step
    /// Critical: Allows fine-tuned adjustments for near-misses
    @Test("Micro-adjust: HARD with low reps drops by micro step")
    func testMicroAdjustHardBelowMin() {
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: 100.0,
            achievedReps: 4,
            repRange: 5...8,
            rating: .hard,
            baseIncrement: 5.0,
            microAdjustStep: 2.5,
            rounding: 2.5
        )

        #expect(result.nextWeight == 97.5)
        #expect(result.nextReps == 5)
    }

    /// Test that EASY rating at max reps increases weight by micro step
    /// Critical: Ensures users progress when they're ready for more
    @Test("Micro-adjust: EASY at max reps adds micro step")
    func testMicroAdjustEasyAtMax() {
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: 100.0,
            achievedReps: 8,
            repRange: 5...8,
            rating: .easy,
            baseIncrement: 5.0,
            microAdjustStep: 2.5,
            rounding: 2.5
        )

        #expect(result.nextWeight == 102.5)
        #expect(result.nextReps == 8)
    }

    // MARK: - Bad-Day Switch Test

    /// Test that bad-day switch activates when first two sets are red (FAIL/HOLY_SHIT)
    /// Critical: Prevents injury by recognizing when user is having an off day
    @Test("Bad-day switch: Activates on two consecutive red sets")
    func testBadDaySwitchActivates() {
        let setLogs = [
            SetLog(setIndex: 1, targetReps: 5, targetWeight: 100.0, achievedReps: 3, rating: .fail, actualWeight: 100.0),
            SetLog(setIndex: 2, targetReps: 5, targetWeight: 95.0, achievedReps: 4, rating: .holyShit, actualWeight: 95.0)
        ]

        let shouldActivate = SteelProgressionEngine.shouldActivateBadDaySwitch(setLogs: setLogs)

        #expect(shouldActivate == true)
    }

    // MARK: - Decision Computation Test

    /// Test UP_1 decision when all sets meet target
    /// Critical: Ensures proper progression when performance warrants it
    @Test("Decision: UP_1 when all meet target")
    func testDecisionUp1() {
        let setLogs = [
            SetLog(setIndex: 1, targetReps: 8, targetWeight: 100.0, achievedReps: 8, rating: .hard, actualWeight: 100.0),
            SetLog(setIndex: 2, targetReps: 8, targetWeight: 100.0, achievedReps: 8, rating: .hard, actualWeight: 100.0),
            SetLog(setIndex: 3, targetReps: 8, targetWeight: 100.0, achievedReps: 7, rating: .hard, actualWeight: 100.0)
        ]

        let decision = SteelProgressionEngine.computeDecision(
            setLogs: setLogs,
            repRange: 5...8,
            totalSets: 3
        )

        #expect(decision == .up_1)
    }

    // MARK: - Next Session Weight Test

    /// Test weekly cap limits weight increase
    /// Critical: Prevents injury from progressing too fast
    @Test("Next session: Weekly cap limits increase")
    func testNextSessionWeightWeeklyCap() {
        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: 100.0,
            decision: .up_2,
            baseIncrement: 10.0,
            rounding: 2.5,
            weeklyCapPct: 5.0,  // Max 5% increase
            recentLoads: [100.0],
            plateOptions: nil
        )

        // Should be capped at 105 (5% of 100), not 120 (2x10)
        #expect(result.startWeight == 105.0)
    }

    // MARK: - Plate Math Test

    /// Test plate rounding for barbell with standard plates
    /// Critical: Ensures prescribed weights are actually achievable with available plates
    @Test("Plate math: Rounds to achievable weight")
    func testPlateRounding() {
        let targetWeight = 137.5  // Bar + 2×46.25 per side (impossible)
        let plates = [45.0, 25.0, 10.0, 5.0, 2.5]
        let barWeight = 45.0

        let achievable = SteelProgressionEngine.roundToPlates(
            targetWeight,
            plates: plates,
            barWeight: barWeight
        )

        // Should round down to 135 (bar + 45 per side)
        #expect(achievable == 135.0)
    }
}
