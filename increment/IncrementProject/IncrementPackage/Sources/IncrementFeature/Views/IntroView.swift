import SwiftUI
import OSLog

@MainActor
struct IntroView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Binding var showAnalytics: Bool
    @Binding var showSettings: Bool
    @State private var showResumePrompt = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Terminal panel with settings button
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("INCREMENT")
                                .font(.system(.largeTitle, design: .monospaced))
                                .fontWeight(.bold)

                            Text("Terminal-inspired lifting tracker")
                                .font(.system(.body, design: .monospaced))
                                .opacity(0.7)
                        }

                        Spacer()

                        Button {
                            showSettings = true
                        } label: {
                            Text("⚙")
                                .font(.system(.title2))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Resume prompt if there's an active session
            if sessionManager.hasResumableSession {
                VStack(spacing: 12) {
                    Text("Previous session detected")
                        .font(.system(.body, design: .monospaced))
                        .opacity(0.7)

                    HStack(spacing: 12) {
                        Button {
                            sessionManager.resumeSession()
                        } label: {
                            Text("RESUME")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button {
                            sessionManager.discardSession()
                        } label: {
                            Text("DISCARD")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
            }

            // Dual Action Buttons
            VStack(spacing: 12) {
                // Start Session Button
                ActionBar {
                    AppLogger.ui.debug("START WORKOUT button tapped")
                    // Discard any existing session when starting a new one
                    if sessionManager.hasResumableSession {
                        sessionManager.discardSession()
                    }
                    sessionManager.showWorkoutSelection()
                } label: {
                    Text(sessionManager.hasResumableSession ? "START NEW WORKOUT" : "START WORKOUT")
                }

                // View Analytics Button
                Button {
                    showAnalytics = true
                } label: {
                    Text("VIEW ANALYTICS")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }
        }
        .foregroundColor(.white)
    }
}
