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
              let template = session.workoutTemplate else {
            return "NEXT EXERCISE"
        }

        if sessionManager.currentExerciseIndex < template.exercises.count - 1 {
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
    @State private var insightsManager = WorkoutInsightsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Session complete header
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

                // AI Insight Panel
                if insightsManager.isGenerating {
                    InsightLoadingView()
                } else if let insight = insightsManager.currentInsight {
                    InsightView(insight: insight)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            ActionBar {
                // Clear the current session completely when workout is done
                sessionManager.discardSession()
            } label: {
                Text("BACK TO START")
            }
        }
    }
}

// MARK: - Insight Views

@MainActor
struct InsightView: View {
    let insight: WorkoutInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(insight.isAIGenerated ? "AI INSIGHT" : "WORKOUT SUMMARY")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                if insight.isAIGenerated {
                    Text("ON-DEVICE")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                }
            }

            // Content
            Text(insight.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

@MainActor
struct InsightLoadingView: View {
    @State private var dots = ""
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("GENERATING INSIGHT\(dots)")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.6))

                Spacer()
            }

            ProgressView()
                .tint(.white)
                .padding(.vertical, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onReceive(timer) { _ in
            dots = dots.count >= 3 ? "" : dots + "."
        }
    }
}
