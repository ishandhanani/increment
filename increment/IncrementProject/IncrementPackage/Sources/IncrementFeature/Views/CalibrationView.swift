import SwiftUI

@MainActor
public struct CalibrationView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Binding var isPresented: Bool

    @State private var benchPress1RM: String = ""
    @State private var squat1RM: String = ""
    @State private var deadlift1RM: String = ""
    @State private var isProcessing = false

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack {
            // Background
            IncrementTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("CALIBRATION")
                            .font(.system(.title, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)

                        Text("Enter your estimated 1RM for these lifts")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // 1RM Inputs
                    VStack(spacing: 24) {
                        CalibrationInputField(
                            title: "BENCH PRESS",
                            value: $benchPress1RM,
                            placeholder: "185"
                        )

                        CalibrationInputField(
                            title: "SQUAT",
                            value: $squat1RM,
                            placeholder: "225"
                        )

                        CalibrationInputField(
                            title: "DEADLIFT",
                            value: $deadlift1RM,
                            placeholder: "275"
                        )
                    }
                    .padding(.horizontal, 24)

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(icon: "→", text: "We'll calculate 70% for starting weights")
                        InfoRow(icon: "→", text: "Accessory exercises estimated automatically")
                        InfoRow(icon: "→", text: "You can recalibrate anytime in Settings")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                    // Actions
                    VStack(spacing: 16) {
                        // Calculate Button
                        Button {
                            applyCalibration()
                        } label: {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Text("CALCULATE WEIGHTS")
                                }
                            }
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.cyan)
                            .cornerRadius(8)
                        }
                        .disabled(!canSubmit || isProcessing)
                        .opacity((canSubmit && !isProcessing) ? 1.0 : 0.5)

                        // Skip Button
                        Button {
                            skipCalibration()
                        } label: {
                            Text("SKIP FOR NOW")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .disabled(isProcessing)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var canSubmit: Bool {
        // At least one 1RM must be provided
        !benchPress1RM.isEmpty || !squat1RM.isEmpty || !deadlift1RM.isEmpty
    }

    private func applyCalibration() {
        isProcessing = true

        // Parse inputs
        let input = CalibrationInput(
            benchPress1RM: Double(benchPress1RM),
            squat1RM: Double(squat1RM),
            deadlift1RM: Double(deadlift1RM)
        )

        // Compute calibration
        let result = CalibrationEngine.calibrate(from: input)

        // Apply to session manager
        sessionManager.exerciseStates = result.exerciseStates

        // Persist
        Task {
            await PersistenceManager.shared.saveExerciseStates(result.exerciseStates)
            await PersistenceManager.shared.saveCalibrationCompleted()

            await MainActor.run {
                isProcessing = false
                isPresented = false
            }
        }
    }

    private func skipCalibration() {
        // Mark as skipped so we don't prompt again
        Task {
            await PersistenceManager.shared.saveCalibrationCompleted()
            isPresented = false
        }
    }
}

// MARK: - Supporting Views

private struct CalibrationInputField: View {
    let title: String
    @Binding var value: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)

            HStack {
                TextField("", text: $value)
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .placeholder(when: value.isEmpty) {
                        Text(placeholder)
                            .font(.system(.title2, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }

                Text("lbs")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.cyan)

            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - View Extension for Placeholder

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
