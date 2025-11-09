import SwiftUI
import IncrementFeature

// MARK: - Warmup View

@MainActor
struct WarmupView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let exerciseLog = sessionManager.currentExerciseLog,
               let profile = sessionManager.exerciseProfiles[exerciseLog.exerciseId] {
                ExerciseHeader(
                    exerciseName: profile.name,
                    setInfo: "Warmup",
                    goal: "\(profile.repRange.lowerBound)–\(profile.repRange.upperBound)",
                    weight: exerciseLog.startWeight,
                    plates: profile.plateOptions.map { plateOptions in
                        SteelProgressionEngine.computePlateBreakdown(
                            exerciseLog.startWeight,
                            plates: plateOptions,
                            barWeight: 45.0
                        )
                    },
                    equipment: profile.equipment
                )
            }

            Spacer()

            // Simplified warmup instruction
            if case .warmup(let step) = sessionManager.sessionState,
               let exerciseLog = sessionManager.currentExerciseLog,
               let exercise = sessionManager.currentSession?.workoutTemplate?.exercises.first(where: { $0.lift.id == exerciseLog.exerciseId }) {
                let exerciseIndex = sessionManager.currentSession?.workoutTemplate?.exercises.firstIndex(where: { $0.lift.id == exerciseLog.exerciseId }) ?? 0
                let warmupPrescription = SteelProgressionEngine.prescribeWarmup(
                    equipment: exercise.lift.equipment,
                    workingWeight: exerciseLog.startWeight,
                    category: exercise.lift.category,
                    priority: exercise.priority,
                    exerciseIndex: exerciseIndex,
                    config: exercise.lift.steelConfig
                )

                VStack(spacing: 24) {
                    // Step indicator
                    Text("Warmup \(step + 1) of \(warmupPrescription.sets.count)")
                        .font(.system(.caption, design: .monospaced))
                        .opacity(0.5)
                        .foregroundColor(.white)

                    // Phase description
                    let phaseText = warmupPhaseText(step: step, totalSets: warmupPrescription.sets.count)
                    Text(phaseText)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("This prepares you for your working sets")
                        .font(.system(.body, design: .monospaced))
                        .opacity(0.7)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            // Action Bar
            ActionBar {
                sessionManager.advanceWarmup()
            } label: {
                if case .warmup(let step) = sessionManager.sessionState,
                   let exerciseLog = sessionManager.currentExerciseLog,
                   let exercise = sessionManager.currentSession?.workoutTemplate?.exercises.first(where: { $0.lift.id == exerciseLog.exerciseId }) {
                    let exerciseIndex = sessionManager.currentSession?.workoutTemplate?.exercises.firstIndex(where: { $0.lift.id == exerciseLog.exerciseId }) ?? 0
                    let warmupPrescription = SteelProgressionEngine.prescribeWarmup(
                        equipment: exercise.lift.equipment,
                        workingWeight: exerciseLog.startWeight,
                        category: exercise.lift.category,
                        priority: exercise.priority,
                        exerciseIndex: exerciseIndex,
                        config: exercise.lift.steelConfig
                    )

                    if step < warmupPrescription.sets.count - 1 {
                        Text("NEXT WARMUP »")
                    } else {
                        Text("START WORKING SETS »")
                    }
                } else {
                    Text("NEXT »")
                }
            }
        }
    }

    private func warmupPhaseText(step: Int, totalSets: Int) -> String {
        if totalSets == 3 {
            switch step {
            case 0:
                return "Start light to warm up"
            case 1:
                return "Increase to medium weight"
            case 2:
                return "One more warmup set"
            default:
                return "Warmup set"
            }
        } else if totalSets == 2 {
            switch step {
            case 0:
                return "Start with lighter weight"
            case 1:
                return "One more warmup set"
            default:
                return "Warmup set"
            }
        } else {
            return "Warmup with lighter weight"
        }
    }
}
