import Foundation

// MARK: - Analytics Extension

extension SessionManager {

    // MARK: - Historical Sessions

    /// Cached sessions for analytics (private storage)
    private static var cachedSessions: [Session]?
    private static var lastCacheRefresh: Date?
    private static let cacheValidityDuration: TimeInterval = 60  // 1 minute

    /// All completed workout sessions (loaded from database with caching)
    public var allSessions: [Session] {
        // Return cached sessions if valid
        if let cached = SessionManager.cachedSessions,
           let lastRefresh = SessionManager.lastCacheRefresh,
           Date().timeIntervalSince(lastRefresh) < SessionManager.cacheValidityDuration {
            return cached.filter { !$0.isActive }  // Only completed sessions
        }

        // Otherwise load synchronously from database
        do {
            let sessions = try DatabaseManager.shared.loadSessionsSync()
            SessionManager.cachedSessions = sessions
            SessionManager.lastCacheRefresh = Date()
            AppLogger.analytics.debug("Loaded \(sessions.count) sessions from database for analytics")
            return sessions.filter { !$0.isActive }  // Only completed sessions
        } catch {
            AppLogger.analytics.error("Failed to load sessions for analytics: \(error.localizedDescription)")
            return []
        }
    }

    /// Refresh sessions from database (invalidates cache)
    public func refreshSessions() async {
        do {
            let sessions = try await DatabaseManager.shared.loadSessions()
            await MainActor.run {
                SessionManager.cachedSessions = sessions
                SessionManager.lastCacheRefresh = Date()
            }
            AppLogger.analytics.debug("Refreshed \(sessions.count) sessions for analytics")
        } catch {
            AppLogger.analytics.error("Failed to refresh sessions: \(error.localizedDescription)")
        }
    }

    /// Force invalidate the cache (useful after completing a workout)
    public func invalidateAnalyticsCache() {
        SessionManager.cachedSessions = nil
        SessionManager.lastCacheRefresh = nil
        AppLogger.analytics.debug("Analytics cache invalidated")
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
        // Build profiles dictionary from performed exercises
        let profilesDict = Dictionary(uniqueKeysWithValues: exercisesPerformed.map { ($0.id, $0) })

        return AnalyticsEngine.calculateVolumeByCategory(
            sessions: allSessions,
            profiles: profilesDict
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
        // Get profile from performed exercises since exerciseProfiles is empty outside active workouts
        guard let profile = exercisesPerformed.first(where: { $0.id == exerciseId }) else { return nil }

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
        // Get unique exercise IDs from all sessions
        let performedIds = Set(allSessions.flatMap { session in
            session.exerciseLogs.map { $0.exerciseId }
        })

        // Build exercise profiles from workout templates in sessions
        // We need to reconstruct profiles since exerciseProfiles dictionary
        // is only populated during active workouts
        var profiles: [String: ExerciseProfile] = [:]

        for session in allSessions {
            if let template = session.workoutTemplate {
                let sessionProfiles = WorkoutTemplateConverter.toExerciseProfiles(from: template)
                profiles.merge(sessionProfiles) { existing, _ in existing }
            }
        }

        // Return profiles for exercises that were actually performed
        return performedIds.compactMap { exerciseId in
            profiles[exerciseId]
        }
        .sorted { $0.name < $1.name }  // Sort alphabetically
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
        let profilesDict = Dictionary(uniqueKeysWithValues: exercisesPerformed.map { ($0.id, $0) })
        if let consistencyInsight = AnalyticsEngine.identifyMostConsistentExercise(
            sessions: allSessions,
            profiles: profilesDict
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
