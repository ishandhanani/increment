import Testing
import Foundation
@testable import IncrementFeature

@Suite("SessionManager Analytics Tests")
@MainActor
struct SessionManagerAnalyticsTests {

    // MARK: - Test Helpers

    func createTestManager() async -> SessionManager {
        // Clear persistence
        PersistenceManager.shared.clearAll()

        let manager = SessionManager()
        return manager
    }

    func createTestSession(date: Date, volume: Double) -> Session {
        var session = Session(
            date: date,
            workoutPlanId: UUID()
        )
        session.stats.totalVolume = volume
        return session
    }

    func saveTestSessions(_ sessions: [Session]) {
        PersistenceManager.shared.saveSessions(sessions)
    }

    // MARK: - All Sessions Tests

    @Test("allSessions loads from persistence")
    func testAllSessionsLoadFromPersistence() async {
        let manager = await createTestManager()

        let sessions = [
            createTestSession(date: Date(), volume: 10000),
            createTestSession(date: Date(), volume: 11000)
        ]
        saveTestSessions(sessions)

        let loaded = manager.allSessions
        #expect(loaded.count == 2)
    }

    // MARK: - Overview Stats Tests

    @Test("overviewStats returns aggregate statistics")
    func testOverviewStatsAggregation() async {
        let manager = await createTestManager()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: yesterday, volume: 11000)
        ]
        saveTestSessions(sessions)

        let stats = manager.overviewStats

        #expect(stats.totalSessions == 2)
        #expect(stats.totalVolume == 21000.0)
        #expect(stats.currentStreak == 2)
    }

    @Test("totalWorkoutsCount returns session count")
    func testTotalWorkoutsCount() async {
        let manager = await createTestManager()

        let sessions = [
            createTestSession(date: Date(), volume: 10000),
            createTestSession(date: Date(), volume: 11000),
            createTestSession(date: Date(), volume: 9500)
        ]
        saveTestSessions(sessions)

        #expect(manager.totalWorkoutsCount == 3)
    }

    @Test("currentStreak calculates consecutive days")
    func testCurrentStreak() async {
        let manager = await createTestManager()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: yesterday, volume: 11000)
        ]
        saveTestSessions(sessions)

        #expect(manager.currentStreak == 2)
    }

    @Test("totalVolumeLifted sums all session volumes")
    func testTotalVolumeLifted() async {
        let manager = await createTestManager()

        let sessions = [
            createTestSession(date: Date(), volume: 10000),
            createTestSession(date: Date(), volume: 12500),
            createTestSession(date: Date(), volume: 8500)
        ]
        saveTestSessions(sessions)

        #expect(manager.totalVolumeLifted == 31000.0)
    }

    // MARK: - Volume Trend Tests

    @Test("volumeTrend returns data for specified days")
    func testVolumeTrendWithDays() async {
        let manager = await createTestManager()
        let calendar = Calendar.current
        let today = Date()
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: today)!
        let fortyDaysAgo = calendar.date(byAdding: .day, value: -40, to: today)!

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: tenDaysAgo, volume: 11000),
            createTestSession(date: fortyDaysAgo, volume: 9500)
        ]
        saveTestSessions(sessions)

        let trend = manager.volumeTrend(days: 30)
        #expect(trend.count == 2) // Only sessions within 30 days
    }

    @Test("volumeBySession returns all sessions sorted")
    func testVolumeBySession() async {
        let manager = await createTestManager()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: twoDaysAgo, volume: 9500),
            createTestSession(date: yesterday, volume: 11000)
        ]
        saveTestSessions(sessions)

        let volumeData = manager.volumeBySession
        #expect(volumeData.count == 3)
        #expect(volumeData[0].date < volumeData[1].date) // Sorted by date
    }

    // MARK: - Volume by Category Tests

    @Test("volumeByCategory breaks down by exercise type")
    func testVolumeByCategoryBreakdown() async {
        let manager = await createTestManager()

        // Create session with exercises
        let benchId = UUID()
        let squatId = UUID()

        // Add profiles to manager
        let benchProfile = ExerciseProfile(
            name: "Bench Press",
            category: .barbell,
            priority: .upper,
            repRange: 5...8,
            sets: 3,
            baseIncrement: 5.0,
            rounding: 2.5,
            weeklyCapPct: 5.0,
            defaultRestSec: 90
        )

        let squatProfile = ExerciseProfile(
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

        manager.exerciseProfiles[benchId] = benchProfile
        manager.exerciseProfiles[squatId] = squatProfile

        // Create set logs
        let benchSets = [
            SetLog(
                setIndex: 1,
                targetReps: 7,
                targetWeight: 185.0,
                achievedReps: 7,
                rating: .hard,
                actualWeight: 185.0
            )
        ]

        let squatSets = [
            SetLog(
                setIndex: 1,
                targetReps: 6,
                targetWeight: 225.0,
                achievedReps: 6,
                rating: .hard,
                actualWeight: 225.0
            )
        ]

        let benchLog = ExerciseSessionLog(
            exerciseId: benchId,
            startWeight: 185.0,
            setLogs: benchSets,
            sessionDecision: .up_1
        )

        let squatLog = ExerciseSessionLog(
            exerciseId: squatId,
            startWeight: 225.0,
            setLogs: squatSets,
            sessionDecision: .up_1
        )

        var session = createTestSession(date: Date(), volume: 2644)
        session.exerciseLogs = [benchLog, squatLog]

        saveTestSessions([session])

        let breakdown = manager.volumeByCategory
        #expect(breakdown.count == 1) // Both are barbell
        #expect(breakdown[0].category == .barbell)
    }

    // MARK: - Exercise Progression Tests

    @Test("progressionData tracks exercise over time")
    func testProgressionDataTracking() async {
        let manager = await createTestManager()
        let exerciseId = UUID()

        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        // Create sessions with exercise
        let sets1 = [
            SetLog(
                setIndex: 1,
                targetReps: 8,
                targetWeight: 135.0,
                achievedReps: 8,
                rating: .easy,
                actualWeight: 135.0
            )
        ]

        let sets2 = [
            SetLog(
                setIndex: 1,
                targetReps: 7,
                targetWeight: 145.0,
                achievedReps: 7,
                rating: .hard,
                actualWeight: 145.0
            )
        ]

        let log1 = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: 135.0,
            setLogs: sets1,
            sessionDecision: .up_1
        )

        let log2 = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: 145.0,
            setLogs: sets2,
            sessionDecision: .up_1
        )

        var session1 = createTestSession(date: weekAgo, volume: 1080)
        session1.exerciseLogs = [log1]

        var session2 = createTestSession(date: today, volume: 1015)
        session2.exerciseLogs = [log2]

        saveTestSessions([session1, session2])

        let progression = manager.progressionData(for: exerciseId)
        #expect(progression.count == 2)
        #expect(progression[0].weight == 135.0)
        #expect(progression[1].weight == 145.0)
    }

    // MARK: - Rating Distribution Tests

    @Test("ratingDistribution calculates percentages")
    func testRatingDistributionCalculation() async {
        let manager = await createTestManager()
        let exerciseId = UUID()

        let sets = [
            SetLog(setIndex: 1, targetReps: 8, targetWeight: 185.0, achievedReps: 8, rating: .easy, actualWeight: 185.0),
            SetLog(setIndex: 2, targetReps: 7, targetWeight: 185.0, achievedReps: 7, rating: .hard, actualWeight: 185.0),
            SetLog(setIndex: 3, targetReps: 7, targetWeight: 185.0, achievedReps: 7, rating: .hard, actualWeight: 185.0),
            SetLog(setIndex: 4, targetReps: 6, targetWeight: 185.0, achievedReps: 6, rating: .holyShit, actualWeight: 185.0)
        ]

        let log = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: 185.0,
            setLogs: sets,
            sessionDecision: .up_1
        )

        var session = createTestSession(date: Date(), volume: 5180)
        session.exerciseLogs = [log]
        saveTestSessions([session])

        let distribution = manager.ratingDistribution
        #expect(distribution.count == 3) // easy, hard, holyShit

        guard let hardRating = distribution.first(where: { $0.rating == .hard }) else {
            Issue.record("Hard rating not found")
            return
        }
        #expect(hardRating.percentage == 50.0)
    }

    // MARK: - Feeling vs Performance Tests

    @Test("feelingVsPerformance includes sessions with feelings")
    func testFeelingVsPerformanceData() async {
        let manager = await createTestManager()

        let feeling1 = PreWorkoutFeeling(rating: 3, note: "tired")
        let feeling2 = PreWorkoutFeeling(rating: 5, note: "energized")

        var session1 = createTestSession(date: Date(), volume: 9000)
        session1.preWorkoutFeeling = feeling1

        var session2 = createTestSession(date: Date(), volume: 12000)
        session2.preWorkoutFeeling = feeling2

        saveTestSessions([session1, session2])

        let data = manager.feelingVsPerformance
        #expect(data.count == 2)
    }

    // MARK: - Calendar Tests

    @Test("sessions(forMonth:) filters by month")
    func testSessionsForMonth() async {
        let manager = await createTestManager()
        let calendar = Calendar.current

        // Create date in current month and previous month
        let thisMonth = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth)!

        let sessions = [
            createTestSession(date: thisMonth, volume: 10000),
            createTestSession(date: thisMonth, volume: 11000),
            createTestSession(date: lastMonth, volume: 9500)
        ]
        saveTestSessions(sessions)

        let thisMonthSessions = manager.sessions(forMonth: thisMonth)
        #expect(thisMonthSessions.count == 2)
    }

    @Test("workoutHeatmap creates date-volume mapping")
    func testWorkoutHeatmapMapping() async {
        let manager = await createTestManager()
        let calendar = Calendar.current

        // Create dates at noon to avoid any timezone/boundary issues
        let now = Date()
        let today = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let sessions = [
            createTestSession(date: today, volume: 10000),
            createTestSession(date: yesterday, volume: 11000)
        ]
        saveTestSessions(sessions)

        let heatmap = manager.workoutHeatmap(forMonth: today)
        #expect(heatmap.count >= 1) // At least one day should be present

        let todayStart = calendar.startOfDay(for: today)
        #expect(heatmap[todayStart] == 10000.0)
    }

    // MARK: - Performance Insights Tests

    @Test("performanceInsights generates insights")
    func testPerformanceInsightsGeneration() async {
        let manager = await createTestManager()
        let calendar = Calendar.current

        // Create consecutive day streak for streak insight
        let today = Date()
        var sessions: [Session] = []

        for i in 0..<8 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            sessions.append(createTestSession(date: date, volume: 10000))
        }

        saveTestSessions(sessions)

        let insights = manager.performanceInsights
        #expect(!insights.isEmpty)

        // Should have streak achievement insight
        let streakInsight = insights.first { $0.type == .streakAchievement }
        #expect(streakInsight != nil)
    }
}
