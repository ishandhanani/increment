import SwiftUI
import IncrementFeature

// MARK: - Warmup View

@MainActor
struct WarmupView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if case .warmup(let step) = sessionManager.sessionState,
               let exerciseLog = sessionManager.currentExerciseLog,
               let exercise = sessionManager.currentSession?.workoutTemplate?.exercises.first(where: { $0.lift.id == exerciseLog.exerciseId }),
               let profile = sessionManager.exerciseProfiles[exerciseLog.exerciseId] {
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
                    // Header
                    Text(profile.name)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    // Simple step indicator
                    VStack(spacing: 8) {
                        Text("Warmup \(step + 1) of \(warmupPrescription.sets.count)")
                            .font(.system(.title, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Grab your weight and complete the set")
                            .font(.system(.body, design: .monospaced))
                            .opacity(0.7)
                            .foregroundColor(.white)
                    }
                }
                .padding(24)
            }

            Spacer()

            // Action Bar
            ActionBar {
                sessionManager.advanceWarmup()
            } label: {
                Text(buttonText)
            }
        }
    }

    private var buttonText: String {
        guard case .warmup(let step) = sessionManager.sessionState,
              let exerciseLog = sessionManager.currentExerciseLog,
              let exercise = sessionManager.currentSession?.workoutTemplate?.exercises.first(where: { $0.lift.id == exerciseLog.exerciseId }) else {
            return "NEXT →"
        }

        let exerciseIndex = sessionManager.currentSession?.workoutTemplate?.exercises.firstIndex(where: { $0.lift.id == exerciseLog.exerciseId }) ?? 0
        let warmupPrescription = SteelProgressionEngine.prescribeWarmup(
            equipment: exercise.lift.equipment,
            workingWeight: exerciseLog.startWeight,
            category: exercise.lift.category,
            priority: exercise.priority,
            exerciseIndex: exerciseIndex,
            config: exercise.lift.steelConfig
        )

        return step < warmupPrescription.sets.count - 1 ? "NEXT WARMUP →" : "START WORKING SETS →"
    }
}
