import SwiftUI
import OSLog

// MARK: - Stretching View

@MainActor
struct StretchingView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if case .stretching(let timeRemaining) = sessionManager.sessionState {
                VStack(spacing: 24) {
                    // Header
                    Text("Stretching")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    // Timer
                    VStack(spacing: 8) {
                        Text(formatTime(timeRemaining))
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Prepare for workout")
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
                sessionManager.finishStretching()
            } label: {
                Text("START WORKOUT →")
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Warmup View

@MainActor
struct WarmupView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let exerciseLog = sessionManager.currentExerciseLog,
               let profile = sessionManager.exerciseProfiles[exerciseLog.exerciseId],
               let exercise = sessionManager.currentSession?.workoutTemplate?.exercises.first(where: { $0.lift.id == exerciseLog.exerciseId }),
               case .warmup(let step) = sessionManager.sessionState {

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
                    Text("Warmup \(step + 1) of \(warmupPrescription.sets.count)")
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
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

// MARK: - Working Set View

@MainActor
struct WorkingSetView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let exerciseLog = sessionManager.currentExerciseLog,
               let profile = sessionManager.exerciseProfiles[exerciseLog.exerciseId],
               let prescription = sessionManager.nextPrescription,
               let exercise = sessionManager.currentSession?.workoutTemplate?.exercises.first(where: { $0.lift.id == exerciseLog.exerciseId }) {
                ExerciseHeader(
                    exerciseId: profile.name,
                    setInfo: "Set \(sessionManager.currentSetIndex + 1)/\(profile.sets)",
                    goal: "\(profile.repRange.lowerBound)–\(profile.repRange.upperBound)",
                    weight: prescription.weight,
                    equipment: exercise.lift.equipment
                )

                Spacer()

                // Content panel - just feeling buttons
                VStack(spacing: 12) {
                    ForEach(Rating.allCases, id: \.self) { rating in
                        Button {
                            // Use prescribed reps - user just rates how it felt
                            sessionManager.logSet(reps: prescription.reps, rating: rating)
                        } label: {
                            Text(rating.rawValue)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(ratingColor(rating))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(24)

                Spacer()
            }
        }
        .foregroundColor(.white)
    }

    private func ratingColor(_ rating: Rating) -> Color {
        switch rating {
        case .fail:
            return Color.red.opacity(0.8)
        case .holyShit:
            return Color.orange.opacity(0.8)
        case .hard:
            return Color.blue.opacity(0.8)
        case .easy:
            return Color.green.opacity(0.8)
        }
    }
}

// MARK: - Rest View

@MainActor
struct RestView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let prescription = sessionManager.nextPrescription,
               case .rest(let timeRemaining) = sessionManager.sessionState {
                VStack(spacing: 24) {
                    // Next prescription
                    VStack(spacing: 8) {
                        Text("Next:")
                            .font(.system(.body, design: .monospaced))
                            .opacity(0.7)

                        Text("\(prescription.reps) × \(Int(prescription.weight)) lb")
                            .font(.system(.title, design: .monospaced))
                            .fontWeight(.bold)
                    }

                    // Rest timer
                    VStack(spacing: 8) {
                        Text("Rest:")
                            .font(.system(.body, design: .monospaced))
                            .opacity(0.7)

                        Text(formatTime(timeRemaining))
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.white)
            }

            Spacer()

            // Action Bar with two controls
            HStack(spacing: 16) {
                Button {
                    sessionManager.adjustRestTime(by: -10)
                } label: {
                    Text("-10s")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    sessionManager.advanceToNextSet()
                } label: {
                    Text("NEXT →")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
