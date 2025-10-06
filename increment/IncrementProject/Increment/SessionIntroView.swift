import SwiftUI
import IncrementFeature

// MARK: - Intro View

@MainActor
struct IntroView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Terminal panel
            VStack(alignment: .leading, spacing: 8) {
                Text("INCREMENT")
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.bold)

                Text("Terminal-inspired lifting tracker")
                    .font(.system(.body, design: .monospaced))
                    .opacity(0.7)

                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")")
                    .font(.system(.caption, design: .monospaced))
                    .opacity(0.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()

            // Action Bar
            ActionBar {
                if let firstPlan = sessionManager.workoutPlans.first {
                    sessionManager.startSession(workoutPlanId: firstPlan.id)
                }
            } label: {
                Text("START SESSION")
            }
        }
        .foregroundColor(.white)
    }
}
