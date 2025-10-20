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

    /// Test warmup for first core exercise (135 lb bench press)
    /// Should have 3 warmup sets with ~15 lb increments
    @Test("Warmup: First core exercise gets 3 warmup sets")
    func testWarmupFirstCoreExercise() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .barbell,
            workingWeight: 135.0,
            category: .push,
            priority: .core,
            exerciseIndex: 0,  // First exercise
            plateOptions: [45.0, 25.0, 10.0, 5.0, 2.5]
        )

        #expect(prescription.needsWarmup == true)
        #expect(prescription.sets.count == 3)

        // Example for 135 lb: working back 3×15 = 90, 105, 120
        // Rounded to plates: likely 90, 105, 115 or similar
        let weights = prescription.sets.map { $0.weight }

        // All warmup weights should be less than working weight
        for weight in weights {
            #expect(weight < 135.0)
        }

        // First warmup should be lightest, last should be closest to working
        #expect(weights.first! < weights.last!)
    }

    /// Test warmup for second core exercise
    /// Should have 1 warmup set (15 lbs less than working)
    @Test("Warmup: Second core exercise gets 1 warmup set")
    func testWarmupSecondCoreExercise() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .barbell,
            workingWeight: 185.0,
            category: .pull,
            priority: .core,
            exerciseIndex: 1,  // Second exercise
            plateOptions: [45.0, 25.0, 10.0, 5.0, 2.5]
        )

        #expect(prescription.needsWarmup == true)
        #expect(prescription.sets.count == 1)

        // Should be ~15 lbs less than working weight
        let warmupWeight = prescription.sets.first?.weight ?? 0
        #expect(warmupWeight >= 165.0)  // At least 185-20
        #expect(warmupWeight <= 175.0)  // At most 185-10
        #expect(warmupWeight < 185.0)   // Less than working weight
    }

    /// Test warmup for third core exercise (if any)
    /// Should get 1 warmup set like second core
    @Test("Warmup: Third+ core exercise gets 1 warmup set")
    func testWarmupThirdCoreExercise() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .barbell,
            workingWeight: 225.0,
            category: .legs,
            priority: .core,
            exerciseIndex: 2,  // Third exercise
            plateOptions: [45.0, 25.0, 10.0, 5.0, 2.5]
        )

        #expect(prescription.needsWarmup == true)
        #expect(prescription.sets.count == 1)

        let warmupWeight = prescription.sets.first?.weight ?? 0
        #expect(warmupWeight >= 205.0)  // ~15 lbs less
        #expect(warmupWeight < 225.0)
    }

    /// Test that accessory exercises skip warmup
    @Test("Warmup: Accessory exercises skip warmup")
    func testWarmupAccessoryExercise() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .barbell,
            workingWeight: 95.0,
            category: .push,
            priority: .accessory,  // Accessory exercise
            exerciseIndex: 3,
            plateOptions: [45.0, 25.0, 10.0, 5.0, 2.5]
        )

        #expect(prescription.needsWarmup == false)
        #expect(prescription.sets.isEmpty)
    }

    /// Test warmup rep scheme decreases with weight
    @Test("Warmup: Rep scheme decreases as weight increases")
    func testWarmupRepScheme() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .barbell,
            workingWeight: 225.0,
            category: .legs,
            priority: .core,
            exerciseIndex: 0,
            plateOptions: [45.0, 25.0, 10.0, 5.0, 2.5]
        )

        #expect(prescription.needsWarmup == true)
        #expect(prescription.sets.count == 3)

        // Rep scheme should decrease or stay same as weight increases
        for (index, set) in prescription.sets.enumerated() {
            if index > 0 {
                let previousSet = prescription.sets[index - 1]
                #expect(set.reps <= previousSet.reps)
            }
        }
    }

    /// Test that bodyweight exercises skip warmup
    @Test("Warmup: Bodyweight exercises skip warmup")
    func testWarmupBodyweight() {
        let prescription = SteelProgressionEngine.prescribeWarmup(
            equipment: .bodyweight,
            workingWeight: 0.0,
            category: .pull,
            priority: .core,
            exerciseIndex: 0
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
            category: .cardio,
            priority: .core,
            exerciseIndex: 0
        )

        #expect(prescription.needsWarmup == false)
        #expect(prescription.sets.isEmpty)
    }
}
