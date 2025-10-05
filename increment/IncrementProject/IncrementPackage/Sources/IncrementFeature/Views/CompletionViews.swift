import SwiftUI

// MARK: - Review View

@MainActor
struct ReviewView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let exerciseLog = sessionManager.currentExerciseLog,
               let decision = exerciseLog.sessionDecision {
                VStack(spacing: 24) {
                    // Decision badge
                    VStack(spacing: 12) {
                        DecisionBadge(decision: decision)

                        Text(decisionReason(decision))
                            .font(.system(.body, design: .monospaced))
                            .opacity(0.7)
                            .multilineTextAlignment(.center)
                    }
                }
                .foregroundColor(.white)
                .padding(24)
            }

            Spacer()

            // Action Bar
            ActionBar {
                sessionManager.advanceToNextExercise()
            } label: {
                Text(nextButtonLabel())
            }
        }
    }

    private func nextButtonLabel() -> String {
        guard let session = sessionManager.currentSession,
              let plan = sessionManager.workoutPlans.first(where: { $0.id == session.workoutPlanId }) else {
            return "NEXT EXERCISE"
        }

        if sessionManager.currentExerciseIndex < plan.order.count - 1 {
            return "NEXT EXERCISE"
        } else {
            return "END SESSION"
        }
    }

    private func decisionReason(_ decision: SessionDecision) -> String {
        switch decision {
        case .up_2:
            return "All sets at top range, felt easy"
        case .up_1:
            return "Hit targets, no failures"
        case .down_1:
            return "Multiple red sets or missed targets"
        case .hold:
            return "Maintaining current load"
        }
    }
}

// MARK: - Done View

@MainActor
struct DoneView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("Session Complete")
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)

                if let session = sessionManager.currentSession {
                    Text("Total Volume: \(Int(session.stats.totalVolume)) lb")
                        .font(.system(.body, design: .monospaced))
                        .opacity(0.7)
                }
            }
            .foregroundColor(.white)

            Spacer()

            ActionBar {
                sessionManager.sessionState = .intro
            } label: {
                Text("BACK TO START")
            }
        }
    }
}
