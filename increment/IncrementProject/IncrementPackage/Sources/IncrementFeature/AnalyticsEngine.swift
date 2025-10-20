import Foundation

/// Engine for processing workout data and generating analytics
public struct AnalyticsEngine {

    // MARK: - Streak Calculation

    /// Calculates the current workout streak (consecutive days with workouts)
    /// - Parameter sessions: All workout sessions sorted by date
    /// - Returns: Number of consecutive days with workouts ending today
    public static func calculateCurrentStreak(sessions: [Session]) -> Int {
        guard !sessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Sort sessions by date descending
        let sortedSessions = sessions.sorted { $0.date > $1.date }

        // Get unique workout dates (start of day)
        let workoutDates = Set(sortedSessions.map { calendar.startOfDay(for: $0.date) })

        var streak = 0
        var currentDate = today

        // Count backwards from today
        while workoutDates.contains(currentDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            currentDate = previousDay
        }

        return streak
    }

    // MARK: - Volume Calculations

    /// Calculates total volume across all sessions
    /// - Parameter sessions: All workout sessions
    /// - Returns: Total volume (weight × reps) in pounds
    public static func calculateTotalVolume(sessions: [Session]) -> Double {
        return sessions.reduce(0.0) { total, session in
            total + session.stats.totalVolume
        }
    }

    /// Calculates average lift weight across all sets
    /// - Parameter sessions: All workout sessions
    /// - Returns: Average weight per set
    public static func calculateAverageLift(sessions: [Session]) -> Double {
        var totalWeight = 0.0
        var totalSets = 0

        for session in sessions {
            for exerciseLog in session.exerciseLogs {
                for setLog in exerciseLog.setLogs {
                    totalWeight += setLog.actualWeight
                    totalSets += 1
                }
            }
        }

        guard totalSets > 0 else { return 0.0 }
        return totalWeight / Double(totalSets)
    }

    /// Generates volume trend data points
    /// - Parameters:
    ///   - sessions: All workout sessions
    ///   - days: Number of days to include (default: 30)
    /// - Returns: Array of volume data points for each session
    public static func generateVolumeTrend(sessions: [Session], days: Int = 30) -> [VolumeDataPoint] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let recentSessions = sessions
            .filter { $0.date >= cutoffDate }
            .sorted { $0.date < $1.date }

        return recentSessions.map { session in
            VolumeDataPoint(
                date: session.date,
                volume: session.stats.totalVolume
            )
        }
    }

    /// Calculates volume breakdown by exercise category
    /// - Parameters:
    ///   - sessions: All workout sessions
    ///   - profiles: Exercise profile lookup
    /// - Returns: Array of volume by category with percentages
    public static func calculateVolumeByCategory(
        sessions: [Session],
        profiles: [String: ExerciseProfile]
    ) -> [VolumeByCategory] {
        var equipmentVolumes: [Equipment: Double] = [:]

        // Sum volume by equipment type
        for session in sessions {
            for exerciseLog in session.exerciseLogs {
                guard let profile = profiles[exerciseLog.exerciseId] else { continue }

                let exerciseVolume = exerciseLog.setLogs.reduce(0.0) { total, setLog in
                    total + (Double(setLog.achievedReps) * setLog.actualWeight)
                }

                equipmentVolumes[profile.equipment, default: 0.0] += exerciseVolume
            }
        }

        let totalVolume = equipmentVolumes.values.reduce(0.0, +)
        guard totalVolume > 0 else { return [] }

        // Convert to array with percentages
        return equipmentVolumes.map { equipment, volume in
            VolumeByCategory(
                equipment: equipment,
                volume: volume,
                percentage: (volume / totalVolume) * 100
            )
        }.sorted { $0.volume > $1.volume }
    }

    // MARK: - Exercise Progression

    /// Generates progression data for a specific exercise
    /// - Parameters:
    ///   - exerciseId: Name of the exercise to track
    ///   - sessions: All workout sessions
    /// - Returns: Array of progression data points
    public static func generateExerciseProgression(
        exerciseId: String,
        sessions: [Session]
    ) -> [ExerciseProgress] {
        let sortedSessions = sessions.sorted { $0.date < $1.date }

        var progressData: [ExerciseProgress] = []

        for session in sortedSessions {
            guard let exerciseLog = session.exerciseLogs.first(where: { $0.exerciseId == exerciseId }) else {
                continue
            }

            let totalVolume = exerciseLog.setLogs.reduce(0.0) { total, setLog in
                total + (Double(setLog.achievedReps) * setLog.actualWeight)
            }

            let totalReps = exerciseLog.setLogs.reduce(0) { $0 + $1.achievedReps }
            let avgReps = exerciseLog.setLogs.isEmpty ? 0.0 : Double(totalReps) / Double(exerciseLog.setLogs.count)

            progressData.append(ExerciseProgress(
                date: session.date,
                weight: exerciseLog.startWeight,
                decision: exerciseLog.sessionDecision ?? .hold,
                volume: totalVolume,
                avgReps: avgReps,
                setCount: exerciseLog.setLogs.count
            ))
        }

        return progressData
    }

    // MARK: - Rating Analysis

    /// Calculates rating distribution across all sets
    /// - Parameter sessions: All workout sessions
    /// - Returns: Array of rating distribution data
    public static func calculateRatingDistribution(sessions: [Session]) -> [RatingDistribution] {
        var ratingCounts: [Rating: Int] = [:]

        for session in sessions {
            for exerciseLog in session.exerciseLogs {
                for setLog in exerciseLog.setLogs {
                    ratingCounts[setLog.rating, default: 0] += 1
                }
            }
        }

        let totalSets = ratingCounts.values.reduce(0, +)
        guard totalSets > 0 else { return [] }

        return Rating.allCases.compactMap { rating in
            guard let count = ratingCounts[rating], count > 0 else { return nil }
            return RatingDistribution(
                rating: rating,
                count: count,
                percentage: (Double(count) / Double(totalSets)) * 100
            )
        }.sorted { $0.count > $1.count }
    }

    // MARK: - Feeling vs Performance

    /// Generates feeling vs performance correlation data
    /// - Parameter sessions: All workout sessions with pre-workout feelings
    /// - Returns: Array of data points correlating feeling with volume
    public static func generateFeelingPerformanceData(sessions: [Session]) -> [FeelingPerformanceData] {
        return sessions.compactMap { session in
            guard let feeling = session.preWorkoutFeeling else { return nil }

            return FeelingPerformanceData(
                date: session.date,
                feeling: feeling.rating,
                volume: session.stats.totalVolume
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Insights Generation

    /// Analyzes feeling vs performance correlation and generates insight
    /// - Parameter data: Feeling-performance data points
    /// - Returns: Insight if significant correlation found, nil otherwise
    public static func analyzeFeelingCorrelation(data: [FeelingPerformanceData]) -> PerformanceInsight? {
        guard data.count >= 5 else { return nil }

        // Group by feeling level and calculate average volume
        var feelingAverages: [Int: Double] = [:]
        var feelingCounts: [Int: Int] = [:]

        for point in data {
            feelingAverages[point.feeling, default: 0.0] += point.volume
            feelingCounts[point.feeling, default: 0] += 1
        }

        // Calculate averages
        for (feeling, total) in feelingAverages {
            let count = feelingCounts[feeling] ?? 1
            feelingAverages[feeling] = total / Double(count)
        }

        // Find best performing feeling level
        guard let bestFeeling = feelingAverages.max(by: { $0.value < $1.value })?.key else {
            return nil
        }

        // Generate insight if it's not feeling level 5 (unexpected pattern)
        if bestFeeling < 5 {
            return PerformanceInsight(
                type: .feelingCorrelation,
                title: "Optimal Feeling Level",
                message: "Your best sessions happen at feeling level \(bestFeeling), not 5! Moderate energy might be your sweet spot."
            )
        }

        return nil
    }

    /// Identifies most consistent exercise based on decision patterns
    /// - Parameters:
    ///   - sessions: All workout sessions
    ///   - profiles: Exercise profiles lookup
    /// - Returns: Insight about most consistent exercise
    public static func identifyMostConsistentExercise(
        sessions: [Session],
        profiles: [String: ExerciseProfile]
    ) -> PerformanceInsight? {
        var exerciseUpDecisions: [String: Int] = [:]
        var exerciseTotalSessions: [String: Int] = [:]

        for session in sessions {
            for exerciseLog in session.exerciseLogs {
                exerciseTotalSessions[exerciseLog.exerciseId, default: 0] += 1

                if case .up_1 = exerciseLog.sessionDecision {
                    exerciseUpDecisions[exerciseLog.exerciseId, default: 0] += 1
                } else if case .up_2 = exerciseLog.sessionDecision {
                    exerciseUpDecisions[exerciseLog.exerciseId, default: 0] += 1
                }
            }
        }

        // Calculate consistency percentage
        var consistencyScores: [(exerciseId: String, score: Double)] = []
        for (exerciseId, upCount) in exerciseUpDecisions {
            let totalSessions = exerciseTotalSessions[exerciseId] ?? 1
            let score = Double(upCount) / Double(totalSessions)
            consistencyScores.append((exerciseId, score))
        }

        guard let best = consistencyScores.max(by: { $0.score < $1.score }),
              let profile = profiles[best.exerciseId],
              best.score > 0.5 else {
            return nil
        }

        return PerformanceInsight(
            type: .consistencyPattern,
            title: "Most Consistent Exercise",
            message: "\(profile.name) is your most consistent lift with \(Int(best.score * 100))% progression rate."
        )
    }

    /// Generates overview statistics
    /// - Parameters:
    ///   - sessions: All workout sessions
    /// - Returns: Aggregate overview stats
    public static func generateOverviewStats(sessions: [Session]) -> OverviewStats {
        return OverviewStats(
            totalSessions: sessions.count,
            totalVolume: calculateTotalVolume(sessions: sessions),
            currentStreak: calculateCurrentStreak(sessions: sessions),
            averageLift: calculateAverageLift(sessions: sessions),
            recentTrend: generateVolumeTrend(sessions: sessions, days: 30)
        )
    }
}
