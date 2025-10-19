import Foundation

/// Computes simplified monthly diagnostic from historical session data
public struct DiagnosticEngine {

    /// Compute diagnostic for the last 30 days
    /// - Parameter sessions: All session history
    /// - Returns: DiagnosticResult with 3 key metrics
    public static func computeMonthlyDiagnostic(sessions: [Session]) -> DiagnosticResult {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate

        // Filter sessions to last 30 days
        let recentSessions = sessions.filter { session in
            session.date >= startDate && session.date <= endDate
        }

        guard !recentSessions.isEmpty else {
            return DiagnosticResult(
                periodStart: startDate,
                periodEnd: endDate,
                averageWeightGain: 0.0,
                badDayFrequency: 0.0,
                stalledLifts: [],
                totalSessions: 0
            )
        }

        // Metric 1: Average weight gain across all exercises
        let avgWeightGain = computeAverageWeightGain(sessions: recentSessions)

        // Metric 2: Bad day frequency
        let badDayFreq = computeBadDayFrequency(sessions: recentSessions)

        // Metric 3: Stalled lifts
        let stalled = computeStalledLifts(sessions: sessions)

        return DiagnosticResult(
            periodStart: startDate,
            periodEnd: endDate,
            averageWeightGain: avgWeightGain,
            badDayFrequency: badDayFreq,
            stalledLifts: stalled,
            totalSessions: recentSessions.count
        )
    }

    // MARK: - Metric Computations

    /// Compute average weight gained across all exercises in the period
    private static func computeAverageWeightGain(sessions: [Session]) -> Double {
        guard !sessions.isEmpty else { return 0.0 }

        // Group exercises by ID
        var exerciseWeights: [String: [Double]] = [:]

        for session in sessions {
            for log in session.exerciseLogs {
                if exerciseWeights[log.exerciseId] == nil {
                    exerciseWeights[log.exerciseId] = []
                }
                exerciseWeights[log.exerciseId]?.append(log.startWeight)
            }
        }

        // Calculate gain for each exercise (last weight - first weight)
        var totalGain = 0.0
        var exerciseCount = 0

        for (_, weights) in exerciseWeights {
            guard weights.count > 1,
                  let first = weights.first,
                  let last = weights.last else {
                continue
            }

            totalGain += (last - first)
            exerciseCount += 1
        }

        guard exerciseCount > 0 else { return 0.0 }
        return totalGain / Double(exerciseCount)
    }

    /// Compute bad day frequency (% of sessions where bad-day switch triggered)
    private static func computeBadDayFrequency(sessions: [Session]) -> Double {
        guard !sessions.isEmpty else { return 0.0 }

        var badDaySessions = 0

        for session in sessions {
            // Check each exercise for bad-day pattern (first 2 sets are red)
            for log in session.exerciseLogs {
                guard log.setLogs.count >= 2 else { continue }

                let firstTwo = Array(log.setLogs.prefix(2))
                let isBadDay = firstTwo.allSatisfy { set in
                    set.rating == .fail || set.rating == .holyShit
                }

                if isBadDay {
                    badDaySessions += 1
                    break  // Count session once even if multiple exercises had bad days
                }
            }
        }

        return (Double(badDaySessions) / Double(sessions.count)) * 100.0
    }

    /// Find exercises that have shown no progress for 3+ weeks
    private static func computeStalledLifts(sessions: [Session]) -> [StalledLift] {
        let calendar = Calendar.current
        let threeWeeksAgo = calendar.date(byAdding: .day, value: -21, to: Date()) ?? Date()

        // Group exercises by ID and track their weights over time
        var exerciseProgress: [String: [(date: Date, weight: Double)]] = [:]

        for session in sessions {
            for log in session.exerciseLogs {
                if exerciseProgress[log.exerciseId] == nil {
                    exerciseProgress[log.exerciseId] = []
                }
                exerciseProgress[log.exerciseId]?.append((date: session.date, weight: log.startWeight))
            }
        }

        var stalledLifts: [StalledLift] = []

        // Check each exercise for stagnation
        for (exerciseId, progressData) in exerciseProgress {
            // Filter to last 3+ weeks
            let recentProgress = progressData.filter { $0.date >= threeWeeksAgo }

            guard recentProgress.count >= 2 else { continue }

            // Sort by date
            let sorted = recentProgress.sorted { $0.date < $1.date }

            guard let first = sorted.first,
                  let last = sorted.last else {
                continue
            }

            // Check if weight hasn't changed or decreased
            let weightChange = last.weight - first.weight

            if weightChange <= 0 {
                // Calculate how many weeks stalled
                let daysBetween = calendar.dateComponents([.day], from: first.date, to: last.date).day ?? 0
                let weeksStalled = max(1, daysBetween / 7)

                // Get exercise name from LiftLibrary
                let exerciseName = LiftLibrary.allLifts.first(where: { $0.id == exerciseId })?.name ?? exerciseId

                stalledLifts.append(StalledLift(
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    weeksStalled: weeksStalled
                ))
            }
        }

        // Sort by weeks stalled (most stalled first)
        return stalledLifts.sorted { $0.weeksStalled > $1.weeksStalled }
    }
}
