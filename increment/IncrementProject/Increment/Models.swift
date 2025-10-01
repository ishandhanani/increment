import Foundation

// MARK: - Enums

enum ExerciseCategory: String, Codable {
    case barbell
    case dumbbell
    case machine
    case bodyweight
}

enum ExercisePriority: String, Codable {
    case upper
    case lower
    case accessory
}

enum Rating: String, Codable, CaseIterable {
    case fail = "FAIL"
    case holyShit = "HOLY_SHIT"
    case hard = "HARD"
    case easy = "EASY"
}

enum SessionDecision: String, Codable {
    case up_2
    case up_1
    case hold
    case down_1
}

// MARK: - ExerciseProfile

struct ExerciseProfile: Codable, Identifiable {
    let id: UUID
    let name: String
    let category: ExerciseCategory
    let priority: ExercisePriority
    let repRange: ClosedRange<Int>
    let sets: Int
    let baseIncrement: Double  // Total load step
    let rounding: Double
    let microAdjustStep: Double?
    let weeklyCapPct: Double  // 5-10%
    let plateOptions: [Double]?  // Per-side plates for barbells
    let warmupRule: String  // "ramped_2" for 50%×5 → 70%×3
    let defaultRestSec: Int

    init(
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

struct ExerciseState: Codable {
    let exerciseId: UUID
    var lastStartLoad: Double
    var lastDecision: SessionDecision?
    var lastUpdatedAt: Date
}

// MARK: - SetLog

struct SetLog: Codable, Identifiable {
    let id: UUID
    let setIndex: Int
    let targetReps: Int
    let targetWeight: Double
    var achievedReps: Int
    var rating: Rating
    let actualWeight: Double
    var restPlannedSec: Int?

    init(
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

struct ExerciseSessionLog: Codable, Identifiable {
    let id: UUID
    let exerciseId: UUID
    let startWeight: Double
    var setLogs: [SetLog]
    var sessionDecision: SessionDecision?
    var nextStartWeight: Double?

    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        startWeight: Double,
        setLogs: [SetLog] = [],
        sessionDecision: SessionDecision? = nil,
        nextStartWeight: Double? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.startWeight = startWeight
        self.setLogs = setLogs
        self.sessionDecision = sessionDecision
        self.nextStartWeight = nextStartWeight
    }
}

// MARK: - PreWorkoutFeeling

struct PreWorkoutFeeling: Codable {
    let rating: Int  // 1-5
    let note: String?  // Optional text description

    init(rating: Int, note: String? = nil) {
        self.rating = rating
        self.note = note
    }
}

// MARK: - Session

struct Session: Codable, Identifiable {
    let id: UUID
    let date: Date
    let workoutPlanId: UUID
    var preWorkoutFeeling: PreWorkoutFeeling?
    var exerciseLogs: [ExerciseSessionLog]
    var stats: SessionStats
    var synced: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        workoutPlanId: UUID,
        preWorkoutFeeling: PreWorkoutFeeling? = nil,
        exerciseLogs: [ExerciseSessionLog] = [],
        stats: SessionStats = SessionStats(totalVolume: 0),
        synced: Bool = false
    ) {
        self.id = id
        self.date = date
        self.workoutPlanId = workoutPlanId
        self.preWorkoutFeeling = preWorkoutFeeling
        self.exerciseLogs = exerciseLogs
        self.stats = stats
        self.synced = synced
    }
}

struct SessionStats: Codable {
    var totalVolume: Double
}

// MARK: - WorkoutPlan

struct WorkoutPlan: Codable, Identifiable {
    let id: UUID
    let name: String
    let order: [UUID]  // exerciseIds in order

    init(id: UUID = UUID(), name: String, order: [UUID]) {
        self.id = id
        self.name = name
        self.order = order
    }
}

// MARK: - Codable Extensions for ClosedRange

extension ClosedRange: Codable where Bound: Codable {
    enum CodingKeys: String, CodingKey {
        case lowerBound
        case upperBound
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lower = try container.decode(Bound.self, forKey: .lowerBound)
        let upper = try container.decode(Bound.self, forKey: .upperBound)
        self = lower...upper
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lowerBound, forKey: .lowerBound)
        try container.encode(upperBound, forKey: .upperBound)
    }
}