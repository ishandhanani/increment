import Testing
import Foundation
@testable import IncrementFeature

@Suite("Analytics Engine Tests")
struct AnalyticsEngineTests {

    // MARK: - Test Helpers

    func createTestSession(date: Date, volume: Double, exercises: [ExerciseSessionLog] = [], feeling: PreWorkoutFeeling? = nil) -> Session {
        var session = Session(
            date: date,
            workoutPlanId: UUID(),
            preWorkoutFeeling: feeling,
            exerciseLogs: exercises
        )
        session.stats.totalVolume = volume
        return session
    }

    func createExerciseLog(exerciseId: UUID, startWeight: Double, decision: SessionDecision, sets: [SetLog]) -> ExerciseSessionLog {
        return ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: startWeight,
            setLogs: sets,
            sessionDecision: decision,
            nextStartWeight: startWeight + 5.0
        )
    }

    func createSetLog(weight: Double, reps: Int, rating: Rating) -> SetLog {
        return SetLog(
            setIndex: 1,
            targetReps: reps,
            targetWeight: weight,
            achievedReps: reps,
            rating: rating,
            actualWeight: weight
        )
    }

    // MARK: - Streak Calculation Tests

    @Test("Streak calculation with no sessions returns zero")
    func testStreakWithNoSessions() {
        let streak = AnalyticsEngine.calculateCurrentStreak(sessions: [])
        #expect(streak == 0)
    }

    @Test("Streak calculation with today's workout returns 1")
    func testStreakWithTodayWorkout() {
        let today = Date()
        let sessions = [createTestSession(date: today, volume: 10000)]

        let streak = AnalyticsEngine.calculateCurrentStreak(sessions: sessions)
        #expect(streak == 1)
    }

    @Test("Streak calculation with consecutive days")
    func testStreakWithConsecutiveDays() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: yesterday, volume: 11000),
            createTestSession(date: twoDaysAgo, volume: 9500)
        ]

        let streak = AnalyticsEngine.calculateCurrentStreak(sessions: sessions)
        #expect(streak == 3)
    }

    @Test("Streak calculation with gap in workouts")
    func testStreakWithGap() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: yesterday, volume: 11000),
            createTestSession(date: threeDaysAgo, volume: 9500)
        ]

        let streak = AnalyticsEngine.calculateCurrentStreak(sessions: sessions)
        #expect(streak == 2) // Only counts today and yesterday
    }

    @Test("Streak calculation with multiple workouts same day")
    func testStreakWithMultipleWorkoutsSameDay() {
        let today = Date()

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: today, volume: 5000) // Same day
        ]

        let streak = AnalyticsEngine.calculateCurrentStreak(sessions: sessions)
        #expect(streak == 1) // Still counts as 1 day
    }

    // MARK: - Volume Calculation Tests

    @Test("Total volume calculation with no sessions")
    func testTotalVolumeNoSessions() {
        let volume = AnalyticsEngine.calculateTotalVolume(sessions: [])
        #expect(volume == 0.0)
    }

    @Test("Total volume calculation with multiple sessions")
    func testTotalVolumeMultipleSessions() {
        let sessions = [
            createTestSession(date: Date(), volume: 10000),
            createTestSession(date: Date(), volume: 12500),
            createTestSession(date: Date(), volume: 11000)
        ]

        let volume = AnalyticsEngine.calculateTotalVolume(sessions: sessions)
        #expect(volume == 33500.0)
    }

    @Test("Average lift calculation with no sessions")
    func testAverageLiftNoSessions() {
        let avg = AnalyticsEngine.calculateAverageLift(sessions: [])
        #expect(avg == 0.0)
    }

    @Test("Average lift calculation with sets")
    func testAverageLiftWithSets() {
        let exerciseId = UUID()
        let sets = [
            createSetLog(weight: 135.0, reps: 8, rating: .easy),
            createSetLog(weight: 185.0, reps: 7, rating: .hard),
            createSetLog(weight: 185.0, reps: 6, rating: .hard)
        ]

        let exerciseLog = createExerciseLog(
            exerciseId: exerciseId,
            startWeight: 135.0,
            decision: .up_1,
            sets: sets
        )

        let session = createTestSession(date: Date(), volume: 3645, exercises: [exerciseLog])

        let avg = AnalyticsEngine.calculateAverageLift(sessions: [session])
        #expect(abs(avg - 168.33) < 0.1) // (135 + 185 + 185) / 3
    }

    // MARK: - Volume Trend Tests

    @Test("Volume trend with no sessions")
    func testVolumeTrendNoSessions() {
        let trend = AnalyticsEngine.generateVolumeTrend(sessions: [], days: 30)
        #expect(trend.isEmpty)
    }

    @Test("Volume trend filters by date range")
    func testVolumeTrendFiltersDateRange() {
        let calendar = Calendar.current
        let today = Date()
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: today)!
        let fortyDaysAgo = calendar.date(byAdding: .day, value: -40, to: today)!

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: tenDaysAgo, volume: 11000),
            createTestSession(date: fortyDaysAgo, volume: 9500)
        ]

        let trend = AnalyticsEngine.generateVolumeTrend(sessions: sessions, days: 30)
        #expect(trend.count == 2) // Only includes sessions within 30 days
    }

    @Test("Volume trend is sorted by date")
    func testVolumeTrendSortedByDate() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: twoDaysAgo, volume: 9500),
            createTestSession(date: yesterday, volume: 11000)
        ]

        let trend = AnalyticsEngine.generateVolumeTrend(sessions: sessions, days: 30)

        #expect(trend.count == 3)
        #expect(trend[0].date < trend[1].date)
        #expect(trend[1].date < trend[2].date)
    }

    // MARK: - Volume by Category Tests

    @Test("Volume by category with no sessions")
    func testVolumeByCategoryNoSessions() {
        let result = AnalyticsEngine.calculateVolumeByCategory(sessions: [], profiles: [:])
        #expect(result.isEmpty)
    }

    @Test("Volume by category calculation")
    func testVolumeByCategoryCalculation() {
        let benchId = UUID()
        let squatId = UUID()

        let profiles: [UUID: ExerciseProfile] = [
            benchId: ExerciseProfile(
                name: "Bench Press",
                category: .barbell,
                priority: .upper,
                repRange: 5...8,
                sets: 3,
                baseIncrement: 5.0,
                rounding: 2.5,
                weeklyCapPct: 5.0,
                defaultRestSec: 90
            ),
            squatId: ExerciseProfile(
                name: "Squat",
                category: .barbell,
                priority: .lower,
                repRange: 5...8,
                sets: 4,
                baseIncrement: 10.0,
                rounding: 5.0,
                weeklyCapPct: 10.0,
                defaultRestSec: 120
            )
        ]

        let benchSets = [createSetLog(weight: 185.0, reps: 7, rating: .hard)]
        let squatSets = [createSetLog(weight: 225.0, reps: 6, rating: .hard)]

        let benchLog = createExerciseLog(exerciseId: benchId, startWeight: 185.0, decision: .up_1, sets: benchSets)
        let squatLog = createExerciseLog(exerciseId: squatId, startWeight: 225.0, decision: .up_1, sets: squatSets)

        let session = createTestSession(date: Date(), volume: 2644, exercises: [benchLog, squatLog])

        let result = AnalyticsEngine.calculateVolumeByCategory(sessions: [session], profiles: profiles)

        #expect(result.count == 1) // Only barbell category
        #expect(result[0].category == .barbell)
        #expect(result[0].percentage == 100.0)
    }

    // MARK: - Exercise Progression Tests

    @Test("Exercise progression with no sessions")
    func testExerciseProgressionNoSessions() {
        let result = AnalyticsEngine.generateExerciseProgression(exerciseId: UUID(), sessions: [])
        #expect(result.isEmpty)
    }

    @Test("Exercise progression tracks weight over time")
    func testExerciseProgressionTracksWeight() {
        let exerciseId = UUID()
        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        let sets1 = [createSetLog(weight: 135.0, reps: 8, rating: .easy)]
        let sets2 = [createSetLog(weight: 145.0, reps: 7, rating: .hard)]

        let log1 = createExerciseLog(exerciseId: exerciseId, startWeight: 135.0, decision: .up_1, sets: sets1)
        let log2 = createExerciseLog(exerciseId: exerciseId, startWeight: 145.0, decision: .up_1, sets: sets2)

        let sessions = [
            createTestSession(date: weekAgo, volume: 1080, exercises: [log1]),
            createTestSession(date: today, volume: 1015, exercises: [log2])
        ]

        let progression = AnalyticsEngine.generateExerciseProgression(exerciseId: exerciseId, sessions: sessions)

        #expect(progression.count == 2)
        #expect(progression[0].weight == 135.0)
        #expect(progression[1].weight == 145.0)
    }

    // MARK: - Rating Distribution Tests

    @Test("Rating distribution with no sessions")
    func testRatingDistributionNoSessions() {
        let result = AnalyticsEngine.calculateRatingDistribution(sessions: [])
        #expect(result.isEmpty)
    }

    @Test("Rating distribution calculates percentages")
    func testRatingDistributionPercentages() {
        let exerciseId = UUID()
        let sets = [
            createSetLog(weight: 185.0, reps: 8, rating: .easy),
            createSetLog(weight: 185.0, reps: 7, rating: .hard),
            createSetLog(weight: 185.0, reps: 7, rating: .hard),
            createSetLog(weight: 185.0, reps: 6, rating: .holyShit)
        ]

        let log = createExerciseLog(exerciseId: exerciseId, startWeight: 185.0, decision: .up_1, sets: sets)
        let session = createTestSession(date: Date(), volume: 5180, exercises: [log])

        let distribution = AnalyticsEngine.calculateRatingDistribution(sessions: [session])

        #expect(distribution.count == 3) // easy, hard, holyShit (no fail)

        // Find hard rating
        guard let hardRating = distribution.first(where: { $0.rating == .hard }) else {
            Issue.record("Hard rating not found")
            return
        }
        #expect(hardRating.percentage == 50.0) // 2 out of 4 sets
    }

    // MARK: - Feeling vs Performance Tests

    @Test("Feeling performance data with no feelings")
    func testFeelingPerformanceNoFeelings() {
        let sessions = [createTestSession(date: Date(), volume: 10000)]
        let result = AnalyticsEngine.generateFeelingPerformanceData(sessions: sessions)
        #expect(result.isEmpty)
    }

    @Test("Feeling performance data includes feeling sessions")
    func testFeelingPerformanceIncludesFeelings() {
        let feeling1 = PreWorkoutFeeling(rating: 3, note: "tired")
        let feeling2 = PreWorkoutFeeling(rating: 5, note: "energized")

        let sessions = [
            createTestSession(date: Date(), volume: 9000, feeling: feeling1),
            createTestSession(date: Date(), volume: 12000, feeling: feeling2)
        ]

        let result = AnalyticsEngine.generateFeelingPerformanceData(sessions: sessions)

        #expect(result.count == 2)
        #expect(result[0].feeling == 3)
        #expect(result[1].feeling == 5)
    }

    // MARK: - Insights Tests

    @Test("Feeling correlation insight with insufficient data")
    func testFeelingCorrelationInsufficientData() {
        let data = [
            FeelingPerformanceData(date: Date(), feeling: 3, volume: 10000),
            FeelingPerformanceData(date: Date(), feeling: 4, volume: 11000)
        ]

        let insight = AnalyticsEngine.analyzeFeelingCorrelation(data: data)
        #expect(insight == nil)
    }

    @Test("Feeling correlation generates insight for unexpected pattern")
    func testFeelingCorrelationGeneratesInsight() {
        let calendar = Calendar.current
        var data: [FeelingPerformanceData] = []

        // Create data where feeling 4 performs best
        for i in 0..<6 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            if i % 2 == 0 {
                data.append(FeelingPerformanceData(date: date, feeling: 4, volume: 12000))
            } else {
                data.append(FeelingPerformanceData(date: date, feeling: 5, volume: 10000))
            }
        }

        let insight = AnalyticsEngine.analyzeFeelingCorrelation(data: data)
        #expect(insight != nil)
        #expect(insight?.type == .feelingCorrelation)
    }

    @Test("Most consistent exercise identification")
    func testMostConsistentExercise() {
        let benchId = UUID()
        let squatId = UUID()

        let profiles: [UUID: ExerciseProfile] = [
            benchId: ExerciseProfile(
                name: "Bench Press",
                category: .barbell,
                priority: .upper,
                repRange: 5...8,
                sets: 3,
                baseIncrement: 5.0,
                rounding: 2.5,
                weeklyCapPct: 5.0,
                defaultRestSec: 90
            ),
            squatId: ExerciseProfile(
                name: "Squat",
                category: .barbell,
                priority: .lower,
                repRange: 5...8,
                sets: 4,
                baseIncrement: 10.0,
                rounding: 5.0,
                weeklyCapPct: 10.0,
                defaultRestSec: 120
            )
        ]

        // Create sessions where bench always progresses
        let sessions = (0..<5).map { i in
            let benchLog = createExerciseLog(
                exerciseId: benchId,
                startWeight: 185.0,
                decision: .up_1,
                sets: [createSetLog(weight: 185.0, reps: 7, rating: .hard)]
            )
            let squatLog = createExerciseLog(
                exerciseId: squatId,
                startWeight: 225.0,
                decision: i % 2 == 0 ? .up_1 : .hold,
                sets: [createSetLog(weight: 225.0, reps: 6, rating: .hard)]
            )
            return createTestSession(date: Date(), volume: 2644, exercises: [benchLog, squatLog])
        }

        let insight = AnalyticsEngine.identifyMostConsistentExercise(sessions: sessions, profiles: profiles)

        #expect(insight != nil)
        #expect(insight?.type == .consistencyPattern)
        #expect(insight?.message.contains("Bench Press") == true)
    }

    // MARK: - Overview Stats Tests

    @Test("Overview stats aggregates all metrics")
    func testOverviewStatsAggregation() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: yesterday, volume: 11000)
        ]

        let stats = AnalyticsEngine.generateOverviewStats(sessions: sessions)

        #expect(stats.totalSessions == 2)
        #expect(stats.totalVolume == 21000.0)
        #expect(stats.currentStreak == 2)
        #expect(stats.recentTrend.count == 2)
    }
}
