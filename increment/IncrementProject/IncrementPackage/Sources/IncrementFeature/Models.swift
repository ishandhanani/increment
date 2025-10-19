import Foundation

// MARK: - Enums

public enum ExerciseCategory: String, Codable, Sendable {
    case barbell
    case dumbbell
    case machine
    case bodyweight
}

public enum ExercisePriority: String, Codable, Sendable {
    case upper
    case lower
    case accessory
}

// MARK: - Workout System Enums

public enum LiftCategory: String, Codable, Sendable, CaseIterable {
    case push
    case pull
    case legs
    case cardio

    /// Returns the next workout type in the cycle
    public var next: LiftCategory {
        let all = LiftCategory.allCases
        guard let currentIndex = all.firstIndex(of: self) else { return .push }
        let nextIndex = (currentIndex + 1) % all.count
        return all[nextIndex]
    }
}

public enum Equipment: String, Codable, Sendable {
    case barbell
    case dumbbell
    case cable
    case machine
    case bodyweight
    case cardioMachine
}

public enum MuscleGroup: String, Codable, Sendable {
    // Push
    case chest
    case shoulders
    case triceps
    // Pull
    case back
    case biceps
    // Legs
    case quads
    case hamstrings
    case glutes
    case calves
    // Core
    case core
}

public enum LiftPriority: String, Codable, Sendable {
    case core       // Main focus lifts
    case accessory  // Supporting/assistance work
}

public enum Rating: String, Codable, Sendable, CaseIterable {
    case fail = "FAIL"
    case holyShit = "HOLY_SHIT"
    case hard = "HARD"
    case easy = "EASY"
}

public enum SessionDecision: String, Codable, Sendable {
    case up_2
    case up_1
    case hold
    case down_1
}

// MARK: - ExerciseProfile

public struct ExerciseProfile: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let category: ExerciseCategory
    public let priority: ExercisePriority
    public let repRange: ClosedRange<Int>
    public let sets: Int
    public let baseIncrement: Double  // Total load step
    public let rounding: Double
    public let microAdjustStep: Double?
    public let weeklyCapPct: Double  // 5-10%
    public let plateOptions: [Double]?  // Per-side plates for barbells
    public let warmupRule: String  // "ramped_2" for 50%×5 → 70%×3
    public let defaultRestSec: Int

    public init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        priority: ExercisePriority,
        repRange: ClosedRange<Int>,
        sets: Int,
        baseIncrement: Double,
        rounding: Double,
        microAdjustStep: Double? = nil,
        weeklyCapPct: Double,
        plateOptions: [Double]? = nil,
        warmupRule: String = "ramped_2",
        defaultRestSec: Int
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.priority = priority
        self.repRange = repRange
        self.sets = sets
        self.baseIncrement = baseIncrement
        self.rounding = rounding
        self.microAdjustStep = microAdjustStep
        self.weeklyCapPct = weeklyCapPct
        self.plateOptions = plateOptions
        self.warmupRule = warmupRule
        self.defaultRestSec = defaultRestSec
    }
}

// MARK: - ExerciseState

public struct ExerciseState: Codable, Sendable {
    public let exerciseName: String
    public var lastStartLoad: Double
    public var lastDecision: SessionDecision?
    public var lastUpdatedAt: Date
}

// MARK: - SetLog

public struct SetLog: Codable, Identifiable, Sendable {
    public let id: UUID
    public let setIndex: Int
    public let targetReps: Int
    public let targetWeight: Double
    public var achievedReps: Int
    public var rating: Rating
    public let actualWeight: Double
    public var restPlannedSec: Int?

    public init(
        id: UUID = UUID(),
        setIndex: Int,
        targetReps: Int,
        targetWeight: Double,
        achievedReps: Int,
        rating: Rating,
        actualWeight: Double,
        restPlannedSec: Int? = nil
    ) {
        self.id = id
        self.setIndex = setIndex
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.achievedReps = achievedReps
        self.rating = rating
        self.actualWeight = actualWeight
        self.restPlannedSec = restPlannedSec
    }
}

// MARK: - ExerciseSessionLog

public struct ExerciseSessionLog: Codable, Identifiable, Sendable {
    public let id: UUID
    public let exerciseName: String
    public let startWeight: Double
    public var setLogs: [SetLog]
    public var sessionDecision: SessionDecision?
    public var nextStartWeight: Double?

    public init(
        id: UUID = UUID(),
        exerciseName: String,
        startWeight: Double,
        setLogs: [SetLog] = [],
        sessionDecision: SessionDecision? = nil,
        nextStartWeight: Double? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.startWeight = startWeight
        self.setLogs = setLogs
        self.sessionDecision = sessionDecision
        self.nextStartWeight = nextStartWeight
    }
}

// MARK: - PreWorkoutFeeling

public struct PreWorkoutFeeling: Codable, Sendable {
    public let rating: Int  // 1-5
    public let note: String?  // Optional text description

    public init(rating: Int, note: String? = nil) {
        self.rating = rating
        self.note = note
    }
}

// MARK: - Session

public struct Session: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public var preWorkoutFeeling: PreWorkoutFeeling?
    public var exerciseLogs: [ExerciseSessionLog]
    public var stats: SessionStats
    public var synced: Bool

    // Session-scoped workout data (stored template for this session)
    public var workoutTemplate: WorkoutTemplate?

    // Resume state fields
    public var isActive: Bool
    public var currentExerciseIndex: Int?
    public var currentSetIndex: Int?
    public var sessionStateRaw: String?  // Serialized SessionState
    public var currentExerciseLog: ExerciseSessionLog?  // In-progress exercise log
    public var lastUpdated: Date

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        preWorkoutFeeling: PreWorkoutFeeling? = nil,
        exerciseLogs: [ExerciseSessionLog] = [],
        stats: SessionStats = SessionStats(totalVolume: 0),
        synced: Bool = false,
        workoutTemplate: WorkoutTemplate? = nil,
        isActive: Bool = true,
        currentExerciseIndex: Int? = nil,
        currentSetIndex: Int? = nil,
        sessionStateRaw: String? = nil,
        currentExerciseLog: ExerciseSessionLog? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.preWorkoutFeeling = preWorkoutFeeling
        self.exerciseLogs = exerciseLogs
        self.stats = stats
        self.synced = synced
        self.workoutTemplate = workoutTemplate
        self.isActive = isActive
        self.currentExerciseIndex = currentExerciseIndex
        self.currentSetIndex = currentSetIndex
        self.sessionStateRaw = sessionStateRaw
        self.currentExerciseLog = currentExerciseLog
        self.lastUpdated = lastUpdated
    }
}

public struct SessionStats: Codable, Sendable {
    public var totalVolume: Double

    public init(totalVolume: Double) {
        self.totalVolume = totalVolume
    }
}

// MARK: - Workout System Models

/// STEEL configuration for a specific lift
public struct SteelConfig: Codable, Sendable {
    public let repRange: ClosedRange<Int>      // e.g., 8...12
    public let baseIncrement: Double           // Total load step
    public let rounding: Double                // Round to nearest X
    public let microAdjustStep: Double?        // Optional micro-loading
    public let weeklyCapPct: Double            // 5-10%
    public let plateOptions: [Double]?         // For barbells: [45, 25, 10, 5, 2.5]
    public let warmupRule: String              // "ramped_2" etc.

    public init(
        repRange: ClosedRange<Int>,
        baseIncrement: Double,
        rounding: Double,
        microAdjustStep: Double? = nil,
        weeklyCapPct: Double,
        plateOptions: [Double]? = nil,
        warmupRule: String = "ramped_2"
    ) {
        self.repRange = repRange
        self.baseIncrement = baseIncrement
        self.rounding = rounding
        self.microAdjustStep = microAdjustStep
        self.weeklyCapPct = weeklyCapPct
        self.plateOptions = plateOptions
        self.warmupRule = warmupRule
    }
}

/// A lift/exercise definition (no UUID - identified by name)
public struct Lift: Codable, Hashable, Sendable {
    public let name: String              // e.g., "Bench Press", "Squat"
    public let category: LiftCategory
    public let equipment: Equipment
    public let muscleGroups: [MuscleGroup]

    // STEEL Configuration (per lift)
    public let steelConfig: SteelConfig

    // Optional metadata
    public let instructions: String?
    public let videoURL: URL?

    public init(
        name: String,
        category: LiftCategory,
        equipment: Equipment,
        muscleGroups: [MuscleGroup],
        steelConfig: SteelConfig,
        instructions: String? = nil,
        videoURL: URL? = nil
    ) {
        self.name = name
        self.category = category
        self.equipment = equipment
        self.muscleGroups = muscleGroups
        self.steelConfig = steelConfig
        self.instructions = instructions
        self.videoURL = videoURL
    }

    // Hashable conformance based on name (unique identifier)
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    public static func == (lhs: Lift, rhs: Lift) -> Bool {
        lhs.name == rhs.name
    }
}

/// Configuration for an exercise within a workout template
public struct WorkoutExercise: Codable, Sendable {
    public let lift: Lift                // The actual lift with STEEL config
    public let order: Int                // Exercise order in workout
    public let priority: LiftPriority    // Core or Accessory
    public let targetSets: Int           // e.g., 3-4 sets
    public let restTime: TimeInterval    // Rest between sets in seconds
    public let notes: String?            // Optional notes

    public init(
        lift: Lift,
        order: Int,
        priority: LiftPriority,
        targetSets: Int,
        restTime: TimeInterval,
        notes: String? = nil
    ) {
        self.lift = lift
        self.order = order
        self.priority = priority
        self.targetSets = targetSets
        self.restTime = restTime
        self.notes = notes
    }
}

/// A workout template (e.g., "Push Day", "Pull Day")
public struct WorkoutTemplate: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String              // "Push Day", "Pull Day", etc.
    public let workoutType: LiftCategory
    public let exercises: [WorkoutExercise]
    public let estimatedDuration: TimeInterval?

    public init(
        id: UUID = UUID(),
        name: String,
        workoutType: LiftCategory,
        exercises: [WorkoutExercise],
        estimatedDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.workoutType = workoutType
        self.exercises = exercises
        self.estimatedDuration = estimatedDuration
    }
}

/// Manages the 4-day workout cycle (Push -> Pull -> Legs -> Cardio)
public struct WorkoutCycle: Codable, Sendable {
    public let templates: [WorkoutTemplate]  // [Push, Pull, Legs, Cardio]
    public var lastCompletedType: LiftCategory?

    public init(templates: [WorkoutTemplate], lastCompletedType: LiftCategory? = nil) {
        self.templates = templates
        self.lastCompletedType = lastCompletedType
    }

    /// Returns the next workout in the cycle
    public func nextWorkout() -> WorkoutTemplate? {
        guard let last = lastCompletedType,
              let nextType = LiftCategory.allCases.first(where: { $0 == last })?.next else {
            // First workout, start with push
            return templates.first { $0.workoutType == .push }
        }

        return templates.first { $0.workoutType == nextType }
    }

    /// Updates the cycle after completing a workout
    public mutating func completeWorkout(_ type: LiftCategory) {
        lastCompletedType = type
    }
}

/// Session status enumeration
public enum SessionStatus: String, Codable, Sendable {
    case inProgress
    case completed
    case abandoned
}

// MARK: - Codable Extensions for ClosedRange
// Note: ClosedRange is already Codable in Swift 6.0+, so this extension is not needed