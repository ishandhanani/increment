import Foundation

/// Central repository for all lift definitions
/// Organized by workout category (Push, Pull, Legs, Cardio)
struct LiftLibrary {

    // MARK: - Push Lifts

    static let benchPress = Lift(
        id: "barbell_bench_press",
        name: "Barbell Bench Press",
        category: .push,
        equipment: .barbell,
        muscleGroups: [.chest, .triceps, .shoulders],
        steelConfig: SteelConfig(
            repRange: 5...8,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0,
            plateOptions: [45, 25, 10, 5, 2.5]
        )
    )

    static let inclineDumbbellBench = Lift(
        id: "incline_dumbbell_bench",
        name: "Incline Dumbbell Bench",
        category: .push,
        equipment: .dumbbell,
        muscleGroups: [.chest, .shoulders],
        steelConfig: SteelConfig(
            repRange: 8...12,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let cableFly = Lift(
        id: "cable_fly",
        name: "Cable Fly",
        category: .push,
        equipment: .cable,
        muscleGroups: [.chest],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let tricepPushdown = Lift(
        id: "tricep_pushdown",
        name: "Tricep Pushdown",
        category: .push,
        equipment: .cable,
        muscleGroups: [.triceps],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let skullcrushers = Lift(
        id: "skullcrushers",
        name: "Skullcrushers",
        category: .push,
        equipment: .barbell,
        muscleGroups: [.triceps],
        steelConfig: SteelConfig(
            repRange: 8...12,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0
        )
    )

    static let overheadPress = Lift(
        id: "overhead_press",
        name: "Overhead Press",
        category: .push,
        equipment: .barbell,
        muscleGroups: [.shoulders, .triceps, .core],
        steelConfig: SteelConfig(
            repRange: 5...8,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0,
            plateOptions: [45, 25, 10, 5, 2.5]
        )
    )

    static let dumbbellPress = Lift(
        id: "dumbbell_press",
        name: "Dumbbell Press",
        category: .push,
        equipment: .dumbbell,
        muscleGroups: [.chest, .shoulders, .triceps],
        steelConfig: SteelConfig(
            repRange: 8...12,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let inclineBarbellBench = Lift(
        id: "incline_barbell_bench",
        name: "Incline Barbell Bench",
        category: .push,
        equipment: .barbell,
        muscleGroups: [.chest, .shoulders, .triceps],
        steelConfig: SteelConfig(
            repRange: 6...10,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0,
            plateOptions: [45, 25, 10, 5, 2.5]
        )
    )

    static let dips = Lift(
        id: "weighted_dips",
        name: "Weighted Dips",
        category: .push,
        equipment: .bodyweight,
        muscleGroups: [.chest, .triceps, .shoulders],
        steelConfig: SteelConfig(
            repRange: 6...10,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0
        )
    )

    static let lateralRaise = Lift(
        id: "lateral_raise",
        name: "Lateral Raise",
        category: .push,
        equipment: .dumbbell,
        muscleGroups: [.shoulders],
        steelConfig: SteelConfig(
            repRange: 12...18,
            baseIncrement: 2.5,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let frontRaise = Lift(
        id: "front_raise",
        name: "Front Raise",
        category: .push,
        equipment: .dumbbell,
        muscleGroups: [.shoulders],
        steelConfig: SteelConfig(
            repRange: 12...18,
            baseIncrement: 2.5,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let rearDeltFly = Lift(
        id: "rear_delt_fly",
        name: "Rear Delt Fly",
        category: .push,
        equipment: .cable,
        muscleGroups: [.shoulders],
        steelConfig: SteelConfig(
            repRange: 12...18,
            baseIncrement: 2.5,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    // MARK: - Pull Lifts

    static let pullups = Lift(
        id: "weighted_pullups",
        name: "Weighted Pull-ups",
        category: .pull,
        equipment: .bodyweight,
        muscleGroups: [.back, .biceps],
        steelConfig: SteelConfig(
            repRange: 5...8,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0
        )
    )

    static let latPulldown = Lift(
        id: "lat_pulldown",
        name: "Lat Pulldown",
        category: .pull,
        equipment: .machine,
        muscleGroups: [.back],
        steelConfig: SteelConfig(
            repRange: 8...12,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let barbellRow = Lift(
        id: "barbell_row",
        name: "Barbell Row",
        category: .pull,
        equipment: .barbell,
        muscleGroups: [.back, .biceps],
        steelConfig: SteelConfig(
            repRange: 6...10,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0,
            plateOptions: [45, 25, 10, 5, 2.5]
        )
    )

    static let dumbbellCurl = Lift(
        id: "dumbbell_curl",
        name: "Dumbbell Curl",
        category: .pull,
        equipment: .dumbbell,
        muscleGroups: [.biceps],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let hammerCurl = Lift(
        id: "hammer_curl",
        name: "Hammer Curl",
        category: .pull,
        equipment: .dumbbell,
        muscleGroups: [.biceps],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let deadlift = Lift(
        id: "barbell_deadlift",
        name: "Barbell Deadlift",
        category: .pull,
        equipment: .barbell,
        muscleGroups: [.back, .hamstrings, .glutes, .core],
        steelConfig: SteelConfig(
            repRange: 3...6,
            baseIncrement: 10.0,
            rounding: 5.0,
            microAdjustStep: 5.0,
            weeklyCapPct: 5.0,
            plateOptions: [45, 25, 10, 5, 2.5]
        )
    )

    static let tBarRow = Lift(
        id: "t_bar_row",
        name: "T-Bar Row",
        category: .pull,
        equipment: .barbell,
        muscleGroups: [.back, .biceps],
        steelConfig: SteelConfig(
            repRange: 6...10,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0
        )
    )

    static let dumbbellRow = Lift(
        id: "dumbbell_row",
        name: "Dumbbell Row",
        category: .pull,
        equipment: .dumbbell,
        muscleGroups: [.back, .biceps],
        steelConfig: SteelConfig(
            repRange: 8...12,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let cableRow = Lift(
        id: "cable_row",
        name: "Cable Row",
        category: .pull,
        equipment: .cable,
        muscleGroups: [.back, .biceps],
        steelConfig: SteelConfig(
            repRange: 8...12,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let cableCurl = Lift(
        id: "cable_curl",
        name: "Cable Curl",
        category: .pull,
        equipment: .cable,
        muscleGroups: [.biceps],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 2.5,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let preacherCurl = Lift(
        id: "preacher_curl",
        name: "Preacher Curl",
        category: .pull,
        equipment: .barbell,
        muscleGroups: [.biceps],
        steelConfig: SteelConfig(
            repRange: 8...12,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let facePull = Lift(
        id: "face_pull",
        name: "Face Pull",
        category: .pull,
        equipment: .cable,
        muscleGroups: [.shoulders, .back],
        steelConfig: SteelConfig(
            repRange: 12...18,
            baseIncrement: 2.5,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let shrugs = Lift(
        id: "shrugs",
        name: "Shrugs",
        category: .pull,
        equipment: .dumbbell,
        muscleGroups: [.back],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    // MARK: - Leg Lifts

    static let squat = Lift(
        id: "barbell_squat",
        name: "Barbell Squat",
        category: .legs,
        equipment: .barbell,
        muscleGroups: [.quads, .glutes, .hamstrings],
        steelConfig: SteelConfig(
            repRange: 5...8,
            baseIncrement: 10.0,
            rounding: 5.0,
            microAdjustStep: 5.0,
            weeklyCapPct: 10.0,
            plateOptions: [45, 25, 10, 5, 2.5]
        )
    )

    static let weightedLunges = Lift(
        id: "weighted_lunges",
        name: "Weighted Lunges",
        category: .legs,
        equipment: .dumbbell,
        muscleGroups: [.quads, .glutes],
        steelConfig: SteelConfig(
            repRange: 8...12,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let legPress = Lift(
        id: "leg_press",
        name: "Leg Press",
        category: .legs,
        equipment: .machine,
        muscleGroups: [.quads, .glutes],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 10.0,
            rounding: 5.0,
            microAdjustStep: 5.0,
            weeklyCapPct: 10.0
        )
    )

    static let calfRaises = Lift(
        id: "calf_raises",
        name: "Calf Raises",
        category: .legs,
        equipment: .machine,
        muscleGroups: [.calves],
        steelConfig: SteelConfig(
            repRange: 12...20,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let frontSquat = Lift(
        id: "front_squat",
        name: "Front Squat",
        category: .legs,
        equipment: .barbell,
        muscleGroups: [.quads, .glutes, .core],
        steelConfig: SteelConfig(
            repRange: 5...8,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0,
            plateOptions: [45, 25, 10, 5, 2.5]
        )
    )

    static let bulgarianSplitSquat = Lift(
        id: "bulgarian_split_squat",
        name: "Bulgarian Split Squat",
        category: .legs,
        equipment: .dumbbell,
        muscleGroups: [.quads, .glutes],
        steelConfig: SteelConfig(
            repRange: 8...12,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let legCurl = Lift(
        id: "leg_curl",
        name: "Leg Curl",
        category: .legs,
        equipment: .machine,
        muscleGroups: [.hamstrings],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let legExtension = Lift(
        id: "leg_extension",
        name: "Leg Extension",
        category: .legs,
        equipment: .machine,
        muscleGroups: [.quads],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let gobletSquat = Lift(
        id: "goblet_squat",
        name: "Goblet Squat",
        category: .legs,
        equipment: .dumbbell,
        muscleGroups: [.quads, .glutes],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    static let stepUps = Lift(
        id: "step_ups",
        name: "Step-ups",
        category: .legs,
        equipment: .dumbbell,
        muscleGroups: [.quads, .glutes],
        steelConfig: SteelConfig(
            repRange: 10...15,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 7.0
        )
    )

    // MARK: - Cardio Lifts

    static let run = Lift(
        id: "two_mile_run",
        name: "2 Mile Run",
        category: .cardio,
        equipment: .cardioMachine,
        muscleGroups: [.core],
        steelConfig: SteelConfig(
            repRange: 1...1,
            baseIncrement: 0,
            rounding: 1.0,
            weeklyCapPct: 0
        )
    )

    static let row = Lift(
        id: "twenty_min_row",
        name: "20 Min Row",
        category: .cardio,
        equipment: .cardioMachine,
        muscleGroups: [.back, .core],
        steelConfig: SteelConfig(
            repRange: 1...1,
            baseIncrement: 0,
            rounding: 1.0,
            weeklyCapPct: 0
        )
    )

    static let bike = Lift(
        id: "thirty_min_bike",
        name: "30 Min Bike",
        category: .cardio,
        equipment: .cardioMachine,
        muscleGroups: [.quads, .core],
        steelConfig: SteelConfig(
            repRange: 1...1,
            baseIncrement: 0,
            rounding: 1.0,
            weeklyCapPct: 0
        )
    )

    // MARK: - Organized Collections

    static let pushLifts: [Lift] = [
        benchPress,
        overheadPress,
        inclineBarbellBench,
        dumbbellPress,
        inclineDumbbellBench,
        dips,
        cableFly,
        tricepPushdown,
        skullcrushers,
        lateralRaise,
        frontRaise,
        rearDeltFly
    ]

    static let pullLifts: [Lift] = [
        deadlift,
        pullups,
        barbellRow,
        tBarRow,
        dumbbellRow,
        cableRow,
        latPulldown,
        dumbbellCurl,
        hammerCurl,
        cableCurl,
        preacherCurl,
        facePull,
        shrugs
    ]

    static let legLifts: [Lift] = [
        squat,
        frontSquat,
        weightedLunges,
        bulgarianSplitSquat,
        gobletSquat,
        legPress,
        stepUps,
        legCurl,
        legExtension,
        calfRaises
    ]

    static let cardioLifts: [Lift] = [
        run,
        row,
        bike,
    ]

    // MARK: - Exercise Pools by Priority

    /// Core compound movements - the main lifts for each category
    static let coreCompoundLifts: [LiftCategory: [Lift]] = [
        .push: [benchPress, overheadPress, inclineBarbellBench, dips],
        .pull: [deadlift, pullups, barbellRow, tBarRow],
        .legs: [squat, frontSquat],
        .cardio: cardioLifts
    ]

    /// Secondary compound movements
    static let secondaryCompoundLifts: [LiftCategory: [Lift]] = [
        .push: [dumbbellPress],
        .pull: [dumbbellRow, cableRow, latPulldown],
        .legs: [weightedLunges, bulgarianSplitSquat, legPress],
        .cardio: []
    ]

    /// Isolation and accessory movements
    static let accessoryLifts: [LiftCategory: [Lift]] = [
        .push: [inclineDumbbellBench, cableFly, tricepPushdown, skullcrushers, lateralRaise, frontRaise, rearDeltFly],
        .pull: [dumbbellCurl, hammerCurl, cableCurl, preacherCurl, facePull, shrugs],
        .legs: [gobletSquat, stepUps, legCurl, legExtension, calfRaises],
        .cardio: []
    ]

    // MARK: - All Lifts

    /// All lifts across all categories
    static let allLifts: [Lift] = pushLifts + pullLifts + legLifts + cardioLifts
}
