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
        let config = SteelConfig(
            repRange: 5...8,
            baseIncrement: 10.0,
            rounding: 2.5,
            weeklyCapPct: 5.0,  // Max 5% increase
            plateOptions: nil
        )

        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: 100.0,
            decision: .up_2,
            config: config,
            recentLoads: [100.0]
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

    // MARK: - Warmup Prescription Tests

    /// Test warmup for 135 lb bench press (user's example)
    /// Critical: Ensures warmup progression matches real-world gym patterns
    @Test("Warmup: 135 lb bench press follows realistic progression")
    func testWarmup135BenchPress() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .barbell,
            workingWeight: 135.0,
            category: .push,
            plateOptions: [45.0, 25.0, 10.0, 5.0, 2.5]
        )

        #expect(prescription.needsWarmup == true)
        #expect(prescription.sets.count >= 2)

        // Should include warmups like: 45 (bar), 95, and possibly 115
        let weights = prescription.sets.map { $0.weight }
        #expect(weights.contains(45.0))  // Bar
        #expect(weights.contains(95.0))  // Standard warmup weight
    }

    /// Test warmup for 185 lb bench press
    /// Should have more warmup sets for heavier weight
    @Test("Warmup: 185 lb bench press has progressive warmup")
    func testWarmup185BenchPress() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .barbell,
            workingWeight: 185.0,
            category: .push,
            plateOptions: [45.0, 25.0, 10.0, 5.0, 2.5]
        )

        #expect(prescription.needsWarmup == true)
        #expect(prescription.sets.count >= 3)

        // Should include: 45, 95, 135, 155 or similar
        let weights = prescription.sets.map { $0.weight }
        #expect(weights.contains(45.0))
        #expect(weights.contains(95.0))
        #expect(weights.contains(135.0))

        // Final warmup should be close to working weight (85-90%)
        if let lastWarmup = weights.last {
            let percentage = lastWarmup / 185.0
            #expect(percentage >= 0.80)  // At least 80% of working weight
            #expect(percentage < 1.0)    // But less than working weight
        }
    }

    /// Test warmup for heavy 315 lb squat
    /// Should have multiple progressive warmup sets
    @Test("Warmup: 315 lb squat has comprehensive warmup")
    func testWarmup315Squat() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .barbell,
            workingWeight: 315.0,
            category: .legs,
            plateOptions: [45.0, 25.0, 10.0, 5.0, 2.5]
        )

        #expect(prescription.needsWarmup == true)
        #expect(prescription.sets.count >= 3)
        #expect(prescription.sets.count <= 5)  // Not too many warmups

        // Should include progressive weights: 45, 95, 135, 185, 225, 275
        let weights = prescription.sets.map { $0.weight }
        #expect(weights.contains(45.0))
        #expect(weights.contains(135.0) || weights.contains(185.0))
        #expect(weights.contains(225.0) || weights.contains(275.0))

        // Rep scheme should decrease as weight increases
        for (index, set) in prescription.sets.enumerated() {
            if index > 0 {
                let previousSet = prescription.sets[index - 1]
                // Heavier warmups should have fewer or equal reps
                #expect(set.reps <= previousSet.reps)
            }
        }
    }

    /// Test warmup for very light weight
    /// Should only have bar or minimal warmup
    @Test("Warmup: Very light weight needs minimal warmup")
    func testWarmupLightWeight() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .barbell,
            workingWeight: 65.0,
            category: .push,
            plateOptions: [45.0, 25.0, 10.0, 5.0, 2.5]
        )

        #expect(prescription.needsWarmup == true)
        // Just the bar
        #expect(prescription.sets.count == 1)
        #expect(prescription.sets.first?.weight == 45.0)
    }

    /// Test warmup for dumbbell exercise
    /// Should have 1-2 warmup sets depending on weight
    @Test("Warmup: Dumbbell exercise has appropriate warmup")
    func testWarmupDumbbell() {
        // Light dumbbell
        let lightPrescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .dumbbell,
            workingWeight: 30.0,
            category: .push
        )
        #expect(lightPrescription.sets.count == 1)

        // Heavy dumbbell
        let heavyPrescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .dumbbell,
            workingWeight: 80.0,
            category: .push
        )
        #expect(heavyPrescription.sets.count == 2)

        // Final warmup should be ~80% of working weight
        if let lastWarmup = heavyPrescription.sets.last {
            let percentage = lastWarmup.weight / 80.0
            #expect(percentage >= 0.75)
            #expect(percentage < 1.0)
        }
    }

    /// Test that bodyweight exercises skip warmup
    @Test("Warmup: Bodyweight exercises skip warmup")
    func testWarmupBodyweight() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .bodyweight,
            workingWeight: 0.0,
            category: .pull
        )

        #expect(prescription.needsWarmup == false)
        #expect(prescription.sets.isEmpty)
    }

    /// Test that cardio exercises skip warmup
    @Test("Warmup: Cardio exercises skip warmup")
    func testWarmupCardio() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .cardioMachine,
            workingWeight: 0.0,
            category: .cardio
        )

        #expect(prescription.needsWarmup == false)
        #expect(prescription.sets.isEmpty)
    }
}
