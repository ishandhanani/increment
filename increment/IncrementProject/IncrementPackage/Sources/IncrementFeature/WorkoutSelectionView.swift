import SwiftUI

public struct WorkoutSelectionView: View {
    @Environment(SessionManager.self) private var sessionManager

    private var suggestedType: LiftCategory {
        sessionManager.suggestedWorkoutType
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Back button header
            HStack {
                Button {
                    sessionManager.cancelWorkoutSelection()
                } label: {
                    HStack(spacing: 6) {
                        Text("←")
                            .font(.system(.body, design: .monospaced))
                        Text("Cancel")
                            .font(.system(.body, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(20)

                Spacer()
            }

            VStack(spacing: 24) {
                Spacer()

                // Workout Type Display
                VStack(spacing: 16) {
                    Text("Today's Workout")
                        .font(.system(.body, design: .monospaced))
                        .opacity(0.7)

                    Text(suggestedType.rawValue.uppercased())
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                // Action Bar
                ActionBar {
                    sessionManager.confirmWorkoutStart()
                } label: {
                    Text("START WORKOUT")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.1, green: 0.15, blue: 0.3))
        .foregroundColor(.white)
    }
}
