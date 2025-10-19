import SwiftUI
import IncrementFeature

// MARK: - Working Set View

@MainActor
struct WorkingSetView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var reps: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let exerciseLog = sessionManager.currentExerciseLog,
               let profile = sessionManager.exerciseProfiles[exerciseLog.exerciseId],
               let prescription = sessionManager.nextPrescription {
                ExerciseHeader(
                    exerciseName: profile.name,
                    setInfo: "Set \(sessionManager.currentSetIndex + 1)/\(profile.sets)",
                    goal: "\(profile.repRange.lowerBound)–\(profile.repRange.upperBound)",
                    weight: prescription.weight,
                    plates: profile.plateOptions.map { plateOptions in
                        SteelProgressionEngine.computePlateBreakdown(
                            prescription.weight,
                            plates: plateOptions,
                            barWeight: 45.0
                        )
                    }
                )

                // Content panel
                VStack(spacing: 24) {
                    // Reps input
                    HStack {
                        Text("Reps:")
                            .font(.system(.body, design: .monospaced))

                        Stepper("\(reps)", value: $reps, in: 0...20)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                    // Rating buttons (SRCL Action List)
                    VStack(spacing: 12) {
                        ForEach(Rating.allCases, id: \.self) { rating in
                            Button {
                                sessionManager.logSet(reps: reps, rating: rating)
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
                }
                .padding(24)
            }

            Spacer()
        }
        .foregroundColor(.white)
        .onAppear {
            if let prescription = sessionManager.nextPrescription {
                reps = prescription.reps
            }
        }
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
                        .foregroundColor(Color(red: 0.1, green: 0.15, blue: 0.3))
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
