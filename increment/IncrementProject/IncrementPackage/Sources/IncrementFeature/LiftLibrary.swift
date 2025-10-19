import Foundation

/// Central repository for all lift definitions
/// Organized by workout category (Push, Pull, Legs, Cardio)
struct LiftLibrary {

    // MARK: - Push Lifts

    static let benchPress = Lift(
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

    // MARK: - Pull Lifts

    static let pullups = Lift(
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

    // MARK: - Leg Lifts

    static let squat = Lift(
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

    // MARK: - Cardio Lifts

    static let run = Lift(
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

    // MARK: - Organized Collections

    static let pushLifts: [Lift] = [
        benchPress,
        inclineDumbbellBench,
        cableFly,
        tricepPushdown,
        skullcrushers
    ]

    static let pullLifts: [Lift] = [
        pullups,
        latPulldown,
        barbellRow,
        dumbbellCurl,
        hammerCurl
    ]

    static let legLifts: [Lift] = [
        squat,
        weightedLunges,
        legPress,
        calfRaises
    ]

    static let cardioLifts: [Lift] = [
        run,
        row
    ]
}
