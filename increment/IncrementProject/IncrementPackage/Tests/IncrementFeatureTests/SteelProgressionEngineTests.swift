import Testing
@testable import IncrementFeature

/// Tests for the S.T.E.E.L. Progression Engine
/// Validates core progression logic including micro-adjustments, decision-making, and weight calculations
@Suite("SteelProgressionEngine Tests")
struct SteelProgressionEngineTests {

    // MARK: - Micro-Adjust Tests

    /// Test that a FAIL rating drops weight by base increment and targets minimum reps
    @Test("Micro-adjust: FAIL rating drops weight and targets min reps")
    func testMicroAdjustFail() {
        // Arrange
        let currentWeight = 100.0
        let achievedReps = 3
        let repRange = 5...8
        let rating = Rating.fail
        let baseIncrement = 5.0
        let microAdjustStep = 2.5
        let rounding = 2.5

        // Act
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: currentWeight,
            achievedReps: achievedReps,
            repRange: repRange,
            rating: rating,
            baseIncrement: baseIncrement,
            microAdjustStep: microAdjustStep,
            rounding: rounding
        )

        // Assert
        #expect(result.nextWeight == 95.0)
        #expect(result.nextReps == 5)
    }

    /// Test that HOLY_SHIT rating with below-min reps drops weight
    @Test("Micro-adjust: HOLY_SHIT with low reps drops weight")
    func testMicroAdjustHolyShitBelowMin() {
        // Arrange
        let currentWeight = 100.0
        let achievedReps = 4
        let repRange = 5...8
        let rating = Rating.holyShit
        let baseIncrement = 5.0
        let microAdjustStep = 2.5
        let rounding = 2.5

        // Act
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: currentWeight,
            achievedReps: achievedReps,
            repRange: repRange,
            rating: rating,
            baseIncrement: baseIncrement,
            microAdjustStep: microAdjustStep,
            rounding: rounding
        )

        // Assert
        #expect(result.nextWeight == 95.0)
        #expect(result.nextReps == 5)
    }

    /// Test that HOLY_SHIT rating at/above min reps holds weight
    @Test("Micro-adjust: HOLY_SHIT at min reps holds weight")
    func testMicroAdjustHolyShitAtMin() {
        // Arrange
        let currentWeight = 100.0
        let achievedReps = 5
        let repRange = 5...8
        let rating = Rating.holyShit
        let baseIncrement = 5.0
        let microAdjustStep = 2.5
        let rounding = 2.5

        // Act
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: currentWeight,
            achievedReps: achievedReps,
            repRange: repRange,
            rating: rating,
            baseIncrement: baseIncrement,
            microAdjustStep: microAdjustStep,
            rounding: rounding
        )

        // Assert
        #expect(result.nextWeight == 100.0)
        #expect(result.nextReps == 5)
    }

    /// Test that HARD rating with below-min reps and micro step drops by micro
    @Test("Micro-adjust: HARD with low reps drops by micro step")
    func testMicroAdjustHardBelowMin() {
        // Arrange
        let currentWeight = 100.0
        let achievedReps = 4
        let repRange = 5...8
        let rating = Rating.hard
        let baseIncrement = 5.0
        let microAdjustStep = 2.5
        let rounding = 2.5

        // Act
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: currentWeight,
            achievedReps: achievedReps,
            repRange: repRange,
            rating: rating,
            baseIncrement: baseIncrement,
            microAdjustStep: microAdjustStep,
            rounding: rounding
        )

        // Assert
        #expect(result.nextWeight == 97.5)
        #expect(result.nextReps == 5)
    }

    /// Test that HARD rating without micro step holds weight
    @Test("Micro-adjust: HARD without micro step holds weight")
    func testMicroAdjustHardNoMicroStep() {
        // Arrange
        let currentWeight = 100.0
        let achievedReps = 4
        let repRange = 5...8
        let rating = Rating.hard
        let baseIncrement = 5.0
        let microAdjustStep: Double? = nil
        let rounding = 2.5

        // Act
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: currentWeight,
            achievedReps: achievedReps,
            repRange: repRange,
            rating: rating,
            baseIncrement: baseIncrement,
            microAdjustStep: microAdjustStep,
            rounding: rounding
        )

        // Assert
        #expect(result.nextWeight == 100.0)
        #expect(result.nextReps == 5)
    }

    /// Test that EASY rating at max reps adds micro step
    @Test("Micro-adjust: EASY at max reps adds micro step")
    func testMicroAdjustEasyAtMax() {
        // Arrange
        let currentWeight = 100.0
        let achievedReps = 8
        let repRange = 5...8
        let rating = Rating.easy
        let baseIncrement = 5.0
        let microAdjustStep = 2.5
        let rounding = 2.5

        // Act
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: currentWeight,
            achievedReps: achievedReps,
            repRange: repRange,
            rating: rating,
            baseIncrement: baseIncrement,
            microAdjustStep: microAdjustStep,
            rounding: rounding
        )

        // Assert
        #expect(result.nextWeight == 102.5)
        #expect(result.nextReps == 8)
    }

    /// Test that EASY rating below max reps holds weight
    @Test("Micro-adjust: EASY below max reps holds weight")
    func testMicroAdjustEasyBelowMax() {
        // Arrange
        let currentWeight = 100.0
        let achievedReps = 6
        let repRange = 5...8
        let rating = Rating.easy
        let baseIncrement = 5.0
        let microAdjustStep = 2.5
        let rounding = 2.5

        // Act
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: currentWeight,
            achievedReps: achievedReps,
            repRange: repRange,
            rating: rating,
            baseIncrement: baseIncrement,
            microAdjustStep: microAdjustStep,
            rounding: rounding
        )

        // Assert
        #expect(result.nextWeight == 100.0)
        #expect(result.nextReps == 6)
    }

    // MARK: - Bad-Day Switch Tests

    /// Test that bad-day switch activates when first two sets are red (FAIL/HOLY_SHIT)
    @Test("Bad-day switch: Activates on two consecutive red sets")
    func testBadDaySwitchActivates() {
        // Arrange
        let setLogs = [
            SetLog(setIndex: 1, targetReps: 5, targetWeight: 100.0, achievedReps: 3, rating: .fail, actualWeight: 100.0),
            SetLog(setIndex: 2, targetReps: 5, targetWeight: 95.0, achievedReps: 4, rating: .holyShit, actualWeight: 95.0)
        ]

        // Act
        let shouldActivate = SteelProgressionEngine.shouldActivateBadDaySwitch(setLogs: setLogs)

        // Assert
        #expect(shouldActivate == true)
    }

    /// Test that bad-day switch does not activate with only one red set
    @Test("Bad-day switch: Does not activate with one red set")
    func testBadDaySwitchDoesNotActivate() {
        // Arrange
        let setLogs = [
            SetLog(setIndex: 1, targetReps: 5, targetWeight: 100.0, achievedReps: 3, rating: .fail, actualWeight: 100.0),
            SetLog(setIndex: 2, targetReps: 5, targetWeight: 95.0, achievedReps: 5, rating: .hard, actualWeight: 95.0)
        ]

        // Act
        let shouldActivate = SteelProgressionEngine.shouldActivateBadDaySwitch(setLogs: setLogs)

        // Assert
        #expect(shouldActivate == false)
    }

    /// Test bad-day adjustment drops weight by base increment
    @Test("Bad-day adjustment: Drops weight by base increment")
    func testBadDayAdjustment() {
        // Arrange
        let currentWeight = 100.0
        let baseIncrement = 5.0
        let rounding = 2.5
        let repRange = 5...8

        // Act
        let result = SteelProgressionEngine.applyBadDayAdjustment(
            currentWeight: currentWeight,
            baseIncrement: baseIncrement,
            rounding: rounding,
            repRange: repRange
        )

        // Assert
        #expect(result.nextWeight == 95.0)
        #expect(result.nextReps == 5)
    }

    // MARK: - Decision Computation Tests

    /// Test UP_2 decision when all sets at max reps and half are easy
    @Test("Decision: UP_2 when all at max and majority easy")
    func testDecisionUp2() {
        // Arrange
        let setLogs = [
            SetLog(setIndex: 1, targetReps: 8, targetWeight: 100.0, achievedReps: 8, rating: .easy, actualWeight: 100.0),
            SetLog(setIndex: 2, targetReps: 8, targetWeight: 100.0, achievedReps: 8, rating: .easy, actualWeight: 100.0),
            SetLog(setIndex: 3, targetReps: 8, targetWeight: 100.0, achievedReps: 8, rating: .hard, actualWeight: 100.0)
        ]
        let repRange = 5...8

        // Act
        let decision = SteelProgressionEngine.computeDecision(
            setLogs: setLogs,
            repRange: repRange,
            totalSets: 3
        )

        // Assert
        #expect(decision == .up_2)
    }

    /// Test UP_1 decision when all sets meet target and hit top
    @Test("Decision: UP_1 when all meet target")
    func testDecisionUp1() {
        // Arrange
        let setLogs = [
            SetLog(setIndex: 1, targetReps: 8, targetWeight: 100.0, achievedReps: 8, rating: .hard, actualWeight: 100.0),
            SetLog(setIndex: 2, targetReps: 8, targetWeight: 100.0, achievedReps: 8, rating: .hard, actualWeight: 100.0),
            SetLog(setIndex: 3, targetReps: 8, targetWeight: 100.0, achievedReps: 7, rating: .hard, actualWeight: 100.0)
        ]
        let repRange = 5...8

        // Act
        let decision = SteelProgressionEngine.computeDecision(
            setLogs: setLogs,
            repRange: repRange,
            totalSets: 3
        )

        // Assert
        #expect(decision == .up_1)
    }

    /// Test HOLD decision for moderate performance
    @Test("Decision: HOLD for moderate performance")
    func testDecisionHold() {
        // Arrange
        let setLogs = [
            SetLog(setIndex: 1, targetReps: 8, targetWeight: 100.0, achievedReps: 7, rating: .hard, actualWeight: 100.0),
            SetLog(setIndex: 2, targetReps: 8, targetWeight: 100.0, achievedReps: 6, rating: .hard, actualWeight: 100.0),
            SetLog(setIndex: 3, targetReps: 8, targetWeight: 100.0, achievedReps: 6, rating: .hard, actualWeight: 100.0)
        ]
        let repRange = 5...8

        // Act
        let decision = SteelProgressionEngine.computeDecision(
            setLogs: setLogs,
            repRange: repRange,
            totalSets: 3
        )

        // Assert
        #expect(decision == .hold)
    }

    /// Test DOWN_1 decision with multiple red sets
    @Test("Decision: DOWN_1 with multiple failures")
    func testDecisionDown1() {
        // Arrange
        let setLogs = [
            SetLog(setIndex: 1, targetReps: 5, targetWeight: 100.0, achievedReps: 3, rating: .fail, actualWeight: 100.0),
            SetLog(setIndex: 2, targetReps: 5, targetWeight: 95.0, achievedReps: 4, rating: .holyShit, actualWeight: 95.0),
            SetLog(setIndex: 3, targetReps: 5, targetWeight: 90.0, achievedReps: 5, rating: .hard, actualWeight: 90.0)
        ]
        let repRange = 5...8

        // Act
        let decision = SteelProgressionEngine.computeDecision(
            setLogs: setLogs,
            repRange: repRange,
            totalSets: 3
        )

        // Assert
        #expect(decision == .down_1)
    }

    // MARK: - Next Session Weight Tests

    /// Test UP_2 decision increases weight by 2x base increment
    @Test("Next session: UP_2 increases by 2x base increment")
    func testNextSessionWeightUp2() {
        // Arrange
        let lastStartLoad = 100.0
        let decision = SessionDecision.up_2
        let baseIncrement = 5.0
        let rounding = 2.5
        let weeklyCapPct = 10.0
        let recentLoads: [Double] = []

        // Act
        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: lastStartLoad,
            decision: decision,
            baseIncrement: baseIncrement,
            rounding: rounding,
            weeklyCapPct: weeklyCapPct,
            recentLoads: recentLoads,
            plateOptions: nil
        )

        // Assert
        #expect(result.startWeight == 110.0)
    }

    /// Test UP_1 decision increases weight by base increment
    @Test("Next session: UP_1 increases by base increment")
    func testNextSessionWeightUp1() {
        // Arrange
        let lastStartLoad = 100.0
        let decision = SessionDecision.up_1
        let baseIncrement = 5.0
        let rounding = 2.5
        let weeklyCapPct = 10.0
        let recentLoads: [Double] = []

        // Act
        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: lastStartLoad,
            decision: decision,
            baseIncrement: baseIncrement,
            rounding: rounding,
            weeklyCapPct: weeklyCapPct,
            recentLoads: recentLoads,
            plateOptions: nil
        )

        // Assert
        #expect(result.startWeight == 105.0)
    }

    /// Test HOLD decision maintains weight
    @Test("Next session: HOLD maintains weight")
    func testNextSessionWeightHold() {
        // Arrange
        let lastStartLoad = 100.0
        let decision = SessionDecision.hold
        let baseIncrement = 5.0
        let rounding = 2.5
        let weeklyCapPct = 10.0
        let recentLoads: [Double] = []

        // Act
        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: lastStartLoad,
            decision: decision,
            baseIncrement: baseIncrement,
            rounding: rounding,
            weeklyCapPct: weeklyCapPct,
            recentLoads: recentLoads,
            plateOptions: nil
        )

        // Assert
        #expect(result.startWeight == 100.0)
    }

    /// Test DOWN_1 decision decreases weight by base increment
    @Test("Next session: DOWN_1 decreases by base increment")
    func testNextSessionWeightDown1() {
        // Arrange
        let lastStartLoad = 100.0
        let decision = SessionDecision.down_1
        let baseIncrement = 5.0
        let rounding = 2.5
        let weeklyCapPct = 10.0
        let recentLoads: [Double] = []

        // Act
        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: lastStartLoad,
            decision: decision,
            baseIncrement: baseIncrement,
            rounding: rounding,
            weeklyCapPct: weeklyCapPct,
            recentLoads: recentLoads,
            plateOptions: nil
        )

        // Assert
        #expect(result.startWeight == 95.0)
    }

    /// Test weekly cap limits weight increase
    @Test("Next session: Weekly cap limits increase")
    func testNextSessionWeightWeeklyCap() {
        // Arrange
        let lastStartLoad = 100.0
        let decision = SessionDecision.up_2
        let baseIncrement = 10.0
        let rounding = 2.5
        let weeklyCapPct = 5.0  // Max 5% increase
        let recentLoads = [100.0]  // Recent load same as start

        // Act
        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: lastStartLoad,
            decision: decision,
            baseIncrement: baseIncrement,
            rounding: rounding,
            weeklyCapPct: weeklyCapPct,
            recentLoads: recentLoads,
            plateOptions: nil
        )

        // Assert - Should be capped at 105 (5% of 100), not 120 (2x10)
        #expect(result.startWeight == 105.0)
    }

    /// Test weight rounds to specified rounding value
    @Test("Next session: Weight rounds correctly")
    func testNextSessionWeightRounding() {
        // Arrange
        let lastStartLoad = 100.0
        let decision = SessionDecision.up_1
        let baseIncrement = 6.0  // Would give 106
        let rounding = 5.0  // Should round to nearest 5
        let weeklyCapPct = 20.0
        let recentLoads: [Double] = []

        // Act
        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: lastStartLoad,
            decision: decision,
            baseIncrement: baseIncrement,
            rounding: rounding,
            weeklyCapPct: weeklyCapPct,
            recentLoads: recentLoads,
            plateOptions: nil
        )

        // Assert - 106 should round to 105
        #expect(result.startWeight == 105.0)
    }

    // MARK: - Plate Math Tests

    /// Test plate rounding for barbell with standard plates
    @Test("Plate math: Rounds to achievable weight with available plates")
    func testPlateRounding() {
        // Arrange
        let targetWeight = 137.5  // Bar + 2×46.25 per side
        let plates = [45.0, 25.0, 10.0, 5.0, 2.5]
        let barWeight = 45.0

        // Act
        let achievable = SteelProgressionEngine.roundToPlates(
            targetWeight,
            plates: plates,
            barWeight: barWeight
        )

        // Assert - Should round down to 135 (bar + 45 per side)
        #expect(achievable == 135.0)
    }

    /// Test plate breakdown computation
    @Test("Plate math: Computes correct plate breakdown")
    func testPlateBreakdown() {
        // Arrange
        let targetWeight = 225.0  // Bar + 90 per side
        let plates = [45.0, 25.0, 10.0, 5.0, 2.5]
        let barWeight = 45.0

        // Act
        let breakdown = SteelProgressionEngine.computePlateBreakdown(
            targetWeight,
            plates: plates,
            barWeight: barWeight
        )

        // Assert - Should be 2×45 per side
        #expect(breakdown == [45.0, 45.0])
    }

    /// Test plate breakdown with mixed plates
    @Test("Plate math: Handles mixed plate combinations")
    func testPlateMixedBreakdown() {
        // Arrange
        let targetWeight = 160.0  // Bar + 57.5 per side
        let plates = [45.0, 25.0, 10.0, 5.0, 2.5]
        let barWeight = 45.0

        // Act
        let breakdown = SteelProgressionEngine.computePlateBreakdown(
            targetWeight,
            plates: plates,
            barWeight: barWeight
        )

        // Assert - Should be 45 + 10 + 2.5 per side
        #expect(breakdown == [45.0, 10.0, 2.5])
    }

    /// Test plate math returns just bar weight when target is too low
    @Test("Plate math: Returns bar weight when target too low")
    func testPlateTooLow() {
        // Arrange
        let targetWeight = 40.0  // Below bar weight
        let plates = [45.0, 25.0, 10.0, 5.0, 2.5]
        let barWeight = 45.0

        // Act
        let achievable = SteelProgressionEngine.roundToPlates(
            targetWeight,
            plates: plates,
            barWeight: barWeight
        )

        // Assert
        #expect(achievable == 45.0)
    }
}
