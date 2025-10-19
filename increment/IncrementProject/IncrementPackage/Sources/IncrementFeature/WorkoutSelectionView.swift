import SwiftUI

public struct WorkoutSelectionView: View {
    @Environment(SessionManager.self) private var sessionManager

    private var suggestedType: LiftCategory {
        sessionManager.suggestedWorkoutType
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Workout Type Display
                VStack(spacing: 16) {
                    Text("Today's Workout")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text(suggestedType.rawValue.uppercased())
                        .font(.system(size: 72, weight: .black, design: .default))
                        .foregroundStyle(.white)
                }

                Spacer()

                // Action Buttons
                VStack(spacing: 16) {
                    Button {
                        sessionManager.confirmWorkoutStart()
                    } label: {
                        Text("START WORKOUT")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        sessionManager.cancelWorkoutSelection()
                    } label: {
                        Text("CANCEL")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
