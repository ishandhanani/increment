import Testing
import Foundation
@testable import IncrementFeature

@Suite("Analytics Models Tests")
struct AnalyticsModelsTests {

    // MARK: - ExerciseProgress Tests

    @Test("ExerciseProgress initializes with all properties")
    func testExerciseProgressInitialization() {
        let date = Date()
        let progress = ExerciseProgress(
            date: date,
            weight: 185.0,
            decision: .up_1,
            volume: 3885.0,
            avgReps: 7.0,
            setCount: 3
        )

        #expect(progress.date == date)
        #expect(progress.weight == 185.0)
        #expect(progress.decision == .up_1)
        #expect(progress.volume == 3885.0)
        #expect(progress.avgReps == 7.0)
        #expect(progress.setCount == 3)
    }

    @Test("ExerciseProgress is Equatable")
    func testExerciseProgressEquality() {
        let date = Date()
        let id = UUID()

        let progress1 = ExerciseProgress(
            id: id,
            date: date,
            weight: 185.0,
            decision: .up_1,
            volume: 3885.0,
            avgReps: 7.0,
            setCount: 3
        )

        let progress2 = ExerciseProgress(
            id: id,
            date: date,
            weight: 185.0,
            decision: .up_1,
            volume: 3885.0,
            avgReps: 7.0,
            setCount: 3
        )

        #expect(progress1 == progress2)
    }

    // MARK: - VolumeDataPoint Tests

    @Test("VolumeDataPoint initializes correctly")
    func testVolumeDataPointInitialization() {
        let date = Date()
        let dataPoint = VolumeDataPoint(date: date, volume: 12500.0)

        #expect(dataPoint.date == date)
        #expect(dataPoint.volume == 12500.0)
    }

    @Test("VolumeDataPoint is Equatable")
    func testVolumeDataPointEquality() {
        let date = Date()
        let id = UUID()

        let point1 = VolumeDataPoint(id: id, date: date, volume: 12500.0)
        let point2 = VolumeDataPoint(id: id, date: date, volume: 12500.0)

        #expect(point1 == point2)
    }

    // MARK: - VolumeByCategory Tests

    @Test("VolumeByCategory initializes with category data")
    func testVolumeByCategoryInitialization() {
        let categoryVolume = VolumeByCategory(
            category: .barbell,
            volume: 8500.0,
            percentage: 65.0
        )

        #expect(categoryVolume.category == .barbell)
        #expect(categoryVolume.volume == 8500.0)
        #expect(categoryVolume.percentage == 65.0)
    }

    @Test("VolumeByCategory percentage calculation is accurate")
    func testVolumeByCategoryPercentage() {
        let totalVolume = 10000.0
        let barbellVolume = 6500.0
        let percentage = (barbellVolume / totalVolume) * 100

        let categoryVolume = VolumeByCategory(
            category: .barbell,
            volume: barbellVolume,
            percentage: percentage
        )

        #expect(categoryVolume.percentage == 65.0)
    }

    // MARK: - RatingDistribution Tests

    @Test("RatingDistribution initializes correctly")
    func testRatingDistributionInitialization() {
        let distribution = RatingDistribution(
            rating: .hard,
            count: 45,
            percentage: 45.0
        )

        #expect(distribution.rating == .hard)
        #expect(distribution.count == 45)
        #expect(distribution.percentage == 45.0)
    }

    @Test("RatingDistribution handles all rating types")
    func testRatingDistributionAllRatings() {
        let ratings: [Rating] = [.easy, .hard, .holyShit, .fail]

        for rating in ratings {
            let distribution = RatingDistribution(
                rating: rating,
                count: 10,
                percentage: 25.0
            )
            #expect(distribution.rating == rating)
        }
    }

    // MARK: - FeelingPerformanceData Tests

    @Test("FeelingPerformanceData initializes correctly")
    func testFeelingPerformanceDataInitialization() {
        let date = Date()
        let data = FeelingPerformanceData(
            date: date,
            feeling: 4,
            volume: 12500.0
        )

        #expect(data.date == date)
        #expect(data.feeling == 4)
        #expect(data.volume == 12500.0)
    }

    @Test("FeelingPerformanceData handles all feeling levels")
    func testFeelingPerformanceDataAllLevels() {
        let date = Date()

        for feeling in 1...5 {
            let data = FeelingPerformanceData(
                date: date,
                feeling: feeling,
                volume: 10000.0
            )
            #expect(data.feeling == feeling)
        }
    }

    // MARK: - PerformanceInsight Tests

    @Test("PerformanceInsight initializes with all fields")
    func testPerformanceInsightInitialization() {
        let date = Date()
        let insight = PerformanceInsight(
            type: .feelingCorrelation,
            title: "Best Performance",
            message: "Your best sessions happen on feeling level 4",
            date: date
        )

        #expect(insight.type == .feelingCorrelation)
        #expect(insight.title == "Best Performance")
        #expect(insight.message == "Your best sessions happen on feeling level 4")
        #expect(insight.date == date)
    }

    @Test("PerformanceInsight handles all insight types")
    func testPerformanceInsightAllTypes() {
        let types: [InsightType] = [
            .feelingCorrelation,
            .consistencyPattern,
            .challengingExercise,
            .bestPerforming,
            .streakAchievement
        ]

        for type in types {
            let insight = PerformanceInsight(
                type: type,
                title: "Test",
                message: "Test message"
            )
            #expect(insight.type == type)
        }
    }

    // MARK: - OverviewStats Tests

    @Test("OverviewStats initializes with all metrics")
    func testOverviewStatsInitialization() {
        let trend = [
            VolumeDataPoint(date: Date(), volume: 10000),
            VolumeDataPoint(date: Date(), volume: 11000)
        ]

        let stats = OverviewStats(
            totalSessions: 24,
            totalVolume: 250000.0,
            currentStreak: 7,
            averageLift: 165.0,
            recentTrend: trend
        )

        #expect(stats.totalSessions == 24)
        #expect(stats.totalVolume == 250000.0)
        #expect(stats.currentStreak == 7)
        #expect(stats.averageLift == 165.0)
        #expect(stats.recentTrend.count == 2)
    }

    @Test("OverviewStats handles empty trend data")
    func testOverviewStatsEmptyTrend() {
        let stats = OverviewStats(
            totalSessions: 0,
            totalVolume: 0.0,
            currentStreak: 0,
            averageLift: 0.0,
            recentTrend: []
        )

        #expect(stats.recentTrend.isEmpty)
    }

    // MARK: - ExerciseSummary Tests

    @Test("ExerciseSummary initializes with all fields")
    func testExerciseSummaryInitialization() {
        let exerciseId = UUID()
        let lastWorkout = Date()

        let summary = ExerciseSummary(
            exerciseId: exerciseId,
            name: "Barbell Bench Press",
            currentWeight: 185.0,
            startingWeight: 135.0,
            totalSessions: 12,
            totalVolume: 42000.0,
            averageRating: 2.5,
            lastWorkout: lastWorkout
        )

        #expect(summary.exerciseId == exerciseId)
        #expect(summary.name == "Barbell Bench Press")
        #expect(summary.currentWeight == 185.0)
        #expect(summary.startingWeight == 135.0)
        #expect(summary.totalSessions == 12)
        #expect(summary.totalVolume == 42000.0)
        #expect(summary.averageRating == 2.5)
        #expect(summary.lastWorkout == lastWorkout)
    }

    @Test("ExerciseSummary calculates weight progression")
    func testExerciseSummaryWeightProgression() {
        let summary = ExerciseSummary(
            exerciseId: UUID(),
            name: "Squat",
            currentWeight: 225.0,
            startingWeight: 185.0,
            totalSessions: 8,
            totalVolume: 50000.0,
            averageRating: 2.0,
            lastWorkout: Date()
        )

        let progression = summary.currentWeight - summary.startingWeight
        #expect(progression == 40.0)
    }

    @Test("ExerciseSummary handles nil lastWorkout")
    func testExerciseSummaryNilLastWorkout() {
        let summary = ExerciseSummary(
            exerciseId: UUID(),
            name: "Deadlift",
            currentWeight: 315.0,
            startingWeight: 275.0,
            totalSessions: 0,
            totalVolume: 0.0,
            averageRating: 0.0,
            lastWorkout: nil
        )

        #expect(summary.lastWorkout == nil)
    }
}
