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
               let profile = sessionManager.exerciseProfiles[exerciseLog.exerciseName] {
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
                    }
                )
            }

            Spacer()

            // Warmup prescription
            if let prescription = sessionManager.getWarmupPrescription() {
                VStack(spacing: 16) {
                    Text("Next warmup:")
                        .font(.system(.body, design: .monospaced))
                        .opacity(0.7)

                    Text("\(prescription.reps) × \(Int(prescription.weight)) lb")
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
            }

            Spacer()

            // Action Bar
            ActionBar {
                sessionManager.advanceWarmup()
            } label: {
                Text("NEXT WARMUP WEIGHT »")
            }
        }
    }
}
