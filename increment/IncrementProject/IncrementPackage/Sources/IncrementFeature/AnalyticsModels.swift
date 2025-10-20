import Foundation

// MARK: - Analytics Data Models

/// Represents progression data for a single exercise over time
public struct ExerciseProgress: Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let weight: Double
    public let decision: SessionDecision
    public let volume: Double
    public let avgReps: Double
    public let setCount: Int

    public init(
        id: UUID = UUID(),
        date: Date,
        weight: Double,
        decision: SessionDecision,
        volume: Double,
        avgReps: Double,
        setCount: Int
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.decision = decision
        self.volume = volume
        self.avgReps = avgReps
        self.setCount = setCount
    }
}

/// Represents volume data for a single data point (session or exercise)
public struct VolumeDataPoint: Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let volume: Double

    public init(id: UUID = UUID(), date: Date, volume: Double) {
        self.id = id
        self.date = date
        self.volume = volume
    }
}

/// Represents volume breakdown by equipment type
public struct VolumeByCategory: Equatable {
    public let equipment: Equipment
    public let volume: Double
    public let percentage: Double

    public init(equipment: Equipment, volume: Double, percentage: Double) {
        self.equipment = equipment
        self.volume = volume
        self.percentage = percentage
    }
}

/// Represents rating distribution statistics
public struct RatingDistribution: Equatable {
    public let rating: Rating
    public let count: Int
    public let percentage: Double

    public init(rating: Rating, count: Int, percentage: Double) {
        self.rating = rating
        self.count = count
        self.percentage = percentage
    }
}

/// Represents correlation between feeling and performance
public struct FeelingPerformanceData: Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let feeling: Int
    public let volume: Double

    public init(id: UUID = UUID(), date: Date, feeling: Int, volume: Double) {
        self.id = id
        self.date = date
        self.feeling = feeling
        self.volume = volume
    }
}

/// Types of insights the analytics engine can generate
public enum InsightType {
    case feelingCorrelation
    case consistencyPattern
    case challengingExercise
    case bestPerforming
    case streakAchievement
}

/// Represents an actionable insight derived from data
public struct PerformanceInsight: Identifiable, Equatable {
    public let id: UUID
    public let type: InsightType
    public let title: String
    public let message: String
    public let date: Date

    public init(
        id: UUID = UUID(),
        type: InsightType,
        title: String,
        message: String,
        date: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.date = date
    }
}

// MARK: - Make InsightType Equatable

extension InsightType: Equatable {}

// MARK: - Overview Statistics

/// Aggregate statistics for overview dashboard
public struct OverviewStats: Equatable {
    public let totalSessions: Int
    public let totalVolume: Double
    public let currentStreak: Int
    public let averageLift: Double
    public let recentTrend: [VolumeDataPoint]

    public init(
        totalSessions: Int,
        totalVolume: Double,
        currentStreak: Int,
        averageLift: Double,
        recentTrend: [VolumeDataPoint]
    ) {
        self.totalSessions = totalSessions
        self.totalVolume = totalVolume
        self.currentStreak = currentStreak
        self.averageLift = averageLift
        self.recentTrend = recentTrend
    }
}

// MARK: - Exercise Summary

/// Summary statistics for a specific exercise
public struct ExerciseSummary: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let currentWeight: Double
    public let startingWeight: Double
    public let totalSessions: Int
    public let totalVolume: Double
    public let averageRating: Double
    public let lastWorkout: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        currentWeight: Double,
        startingWeight: Double,
        totalSessions: Int,
        totalVolume: Double,
        averageRating: Double,
        lastWorkout: Date?
    ) {
        self.id = id
        self.name = name
        self.currentWeight = currentWeight
        self.startingWeight = startingWeight
        self.totalSessions = totalSessions
        self.totalVolume = totalVolume
        self.averageRating = averageRating
        self.lastWorkout = lastWorkout
    }
}
