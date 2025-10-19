import Foundation

// MARK: - Analytics Extension

extension SessionManager {

    // MARK: - Historical Sessions

    /// All completed workout sessions
    public var allSessions: [Session] {
        return PersistenceManager.shared.loadSessions()
    }

    // MARK: - Overview Statistics

    /// Quick stats for overview dashboard
    public var overviewStats: OverviewStats {
        let sessions = allSessions
        return AnalyticsEngine.generateOverviewStats(sessions: sessions)
    }

    /// Total number of completed workouts
    public var totalWorkoutsCount: Int {
        return allSessions.count
    }

    /// Current workout streak (consecutive days)
    public var currentStreak: Int {
        return AnalyticsEngine.calculateCurrentStreak(sessions: allSessions)
    }

    /// Total volume lifted across all workouts
    public var totalVolumeLifted: Double {
        return AnalyticsEngine.calculateTotalVolume(sessions: allSessions)
    }

    /// Average lift weight across all sets
    public var averageLiftWeight: Double {
        return AnalyticsEngine.calculateAverageLift(sessions: allSessions)
    }

    // MARK: - Volume Analytics

    /// Volume trend for last N days
    /// - Parameter days: Number of days to include (default: 30)
    /// - Returns: Array of volume data points
    public func volumeTrend(days: Int = 30) -> [VolumeDataPoint] {
        return AnalyticsEngine.generateVolumeTrend(sessions: allSessions, days: days)
    }

    /// Volume breakdown by exercise category
    public var volumeByCategory: [VolumeByCategory] {
        return AnalyticsEngine.calculateVolumeByCategory(
            sessions: allSessions,
            profiles: exerciseProfiles
        )
    }

    /// Volume data points for each session
    public var volumeBySession: [VolumeDataPoint] {
        return allSessions
            .sorted { $0.date < $1.date }
            .map { VolumeDataPoint(date: $0.date, volume: $0.stats.totalVolume) }
    }

    // MARK: - Exercise Progression

    /// Get progression data for a specific exercise
    /// - Parameter exerciseId: Name of the exercise to track
    /// - Returns: Array of progression data points
    public func progressionData(for exerciseId: String) -> [ExerciseProgress] {
        return AnalyticsEngine.generateExerciseProgression(
            exerciseId: exerciseId,
            sessions: allSessions
        )
    }

    /// Get summary statistics for a specific exercise
    /// - Parameter exerciseId: Name of the exercise
    /// - Returns: Exercise summary with stats
    public func exerciseSummary(for exerciseId: String) -> ExerciseSummary? {
        guard let profile = exerciseProfiles[exerciseId] else { return nil }

        let exerciseSessions = allSessions.filter { session in
            session.exerciseLogs.contains { $0.exerciseId == exerciseId }
        }

        guard !exerciseSessions.isEmpty else { return nil }

        // Calculate stats
        let totalVolume = exerciseSessions.reduce(0.0) { total, session in
            guard let log = session.exerciseLogs.first(where: { $0.exerciseId == exerciseId }) else {
                return total
            }
            let logVolume = log.setLogs.reduce(0.0) { $0 + (Double($1.achievedReps) * $1.actualWeight) }
            return total + logVolume
        }

        // Get current and starting weights
        let progression = progressionData(for: exerciseId)
        let currentWeight = progression.last?.weight ?? 0.0
        let startingWeight = progression.first?.weight ?? 0.0

        // Calculate average rating (convert to numeric)
        var totalRatingScore = 0.0
        var ratingCount = 0

        for session in exerciseSessions {
            guard let log = session.exerciseLogs.first(where: { $0.exerciseId == exerciseId }) else {
                continue
            }
            for setLog in log.setLogs {
                totalRatingScore += ratingToScore(setLog.rating)
                ratingCount += 1
            }
        }

        let avgRating = ratingCount > 0 ? totalRatingScore / Double(ratingCount) : 0.0

        // Last workout date
        let lastWorkout = exerciseSessions.sorted { $0.date > $1.date }.first?.date

        return ExerciseSummary(
            name: profile.name,
            currentWeight: currentWeight,
            startingWeight: startingWeight,
            totalSessions: exerciseSessions.count,
            totalVolume: totalVolume,
            averageRating: avgRating,
            lastWorkout: lastWorkout
        )
    }

    /// List of all exercises that have been performed
    public var exercisesPerformed: [ExerciseProfile] {
        let performedNames = Set(allSessions.flatMap { session in
            session.exerciseLogs.map { $0.exerciseId }
        })

        return performedNames.compactMap { exerciseProfiles[$0] }
    }

    // MARK: - Performance Insights

    /// Feeling vs performance correlation data
    public var feelingVsPerformance: [FeelingPerformanceData] {
        return AnalyticsEngine.generateFeelingPerformanceData(sessions: allSessions)
    }

    /// Rating distribution across all sets
    public var ratingDistribution: [RatingDistribution] {
        return AnalyticsEngine.calculateRatingDistribution(sessions: allSessions)
    }

    /// Generate performance insights
    public var performanceInsights: [PerformanceInsight] {
        var insights: [PerformanceInsight] = []

        // Feeling correlation insight
        let feelingData = feelingVsPerformance
        if let feelingInsight = AnalyticsEngine.analyzeFeelingCorrelation(data: feelingData) {
            insights.append(feelingInsight)
        }

        // Consistency insight
        if let consistencyInsight = AnalyticsEngine.identifyMostConsistentExercise(
            sessions: allSessions,
            profiles: exerciseProfiles
        ) {
            insights.append(consistencyInsight)
        }

        // Add streak achievement insight if applicable
        let streak = currentStreak
        if streak >= 7 {
            insights.append(PerformanceInsight(
                type: .streakAchievement,
                title: "Consistency Achievement",
                message: "Amazing! You've maintained a \(streak)-day workout streak. Keep it up!"
            ))
        }

        return insights
    }

    // MARK: - Calendar Data

    /// Get all sessions for a specific month
    /// - Parameter date: Any date within the target month
    /// - Returns: Array of sessions in that month
    public func sessions(forMonth date: Date) -> [Session] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return []
        }

        return allSessions.filter { session in
            session.date >= monthInterval.start && session.date < monthInterval.end
        }
    }

    /// Get workout dates for a specific month (for heatmap)
    /// - Parameter date: Any date within the target month
    /// - Returns: Dictionary mapping dates to volume
    public func workoutHeatmap(forMonth date: Date) -> [Date: Double] {
        let calendar = Calendar.current
        let sessions = self.sessions(forMonth: date)

        var heatmap: [Date: Double] = [:]
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.date)
            heatmap[dayStart, default: 0.0] += session.stats.totalVolume
        }

        return heatmap
    }

    // MARK: - Helper Methods

    /// Convert rating enum to numeric score for averaging
    /// - Parameter rating: Set rating
    /// - Returns: Numeric score (0-3)
    private func ratingToScore(_ rating: Rating) -> Double {
        switch rating {
        case .fail:
            return 0.0
        case .holyShit:
            return 1.0
        case .hard:
            return 2.0
        case .easy:
            return 3.0
        }
    }
}
