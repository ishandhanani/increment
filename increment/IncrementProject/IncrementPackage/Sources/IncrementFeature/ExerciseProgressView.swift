import SwiftUI
import Charts

// MARK: - Exercise Progress View

@MainActor
struct ExerciseProgressView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var selectedExerciseId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Exercise Selector
                if !sessionManager.exercisesPerformed.isEmpty {
                    ExerciseSelector(
                        exercises: sessionManager.exercisesPerformed,
                        selectedName: $selectedExerciseId
                    )

                    // Progression Chart
                    if let exerciseId = selectedExerciseId {
                        ProgressionChart(
                            progression: sessionManager.progressionData(for: exerciseId)
                        )

                        // Exercise Summary
                        if let summary = sessionManager.exerciseSummary(for: exerciseId) {
                            ExerciseSummaryCard(summary: summary)
                        }
                    } else {
                        EmptyProgressionMessage()
                    }
                } else {
                    NoDataMessage()
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(24)
        }
        .onAppear {
            // Select first exercise by default
            if selectedExerciseId == nil,
               let firstExercise = sessionManager.exercisesPerformed.first {
                selectedExerciseId = firstExercise.name
            }
        }
    }
}

// MARK: - Exercise Selector

struct ExerciseSelector: View {
    let exercises: [ExerciseProfile]
    @Binding var selectedName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECT EXERCISE")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            Menu {
                ForEach(exercises) { exercise in
                    Button(exercise.name) {
                        selectedName = exercise.name
                    }
                }
            } label: {
                HStack {
                    if let selected = exercises.first(where: { $0.name == selectedName }) {
                        Text(selected.name)
                    } else {
                        Text("Select Exercise")
                    }

                    Spacer()

                    Text("▾")
                }
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Progression Chart

struct ProgressionChart: View {
    let progression: [ExerciseProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEIGHT PROGRESSION")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            if progression.isEmpty {
                EmptyProgressionMessage()
            } else {
                Chart(progression) { dataPoint in
                    // Line
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(.white)
                    .interpolationMethod(.catmullRom)

                    // Points with decision colors
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(colorForDecision(dataPoint.decision))
                    .symbolSize(60)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
                .frame(height: 200)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                // Legend
                DecisionLegend()
            }
        }
    }

    private func colorForDecision(_ decision: SessionDecision) -> Color {
        switch decision {
        case .up_2, .up_1:
            return .green.opacity(0.8)
        case .hold:
            return .white.opacity(0.5)
        case .down_1:
            return .red.opacity(0.8)
        }
    }
}

// MARK: - Decision Legend

struct DecisionLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            LegendItem(color: .green.opacity(0.8), label: "UP")
            LegendItem(color: .white.opacity(0.5), label: "HOLD")
            LegendItem(color: .red.opacity(0.8), label: "DOWN")
        }
        .font(.system(.caption2, design: .monospaced))
        .padding(.top, 8)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Exercise Summary Card

struct ExerciseSummaryCard: View {
    let summary: ExerciseSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SUMMARY")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            VStack(spacing: 12) {
                SummaryRow(
                    label: "Current Weight",
                    value: "\(Int(summary.currentWeight)) lb"
                )

                SummaryRow(
                    label: "Starting Weight",
                    value: "\(Int(summary.startingWeight)) lb"
                )

                SummaryRow(
                    label: "Progress",
                    value: "+\(Int(summary.currentWeight - summary.startingWeight)) lb",
                    highlight: true
                )

                SummaryRow(
                    label: "Total Sessions",
                    value: "\(summary.totalSessions)"
                )

                SummaryRow(
                    label: "Total Volume",
                    value: formatVolume(summary.totalVolume)
                )

                if let lastWorkout = summary.lastWorkout {
                    SummaryRow(
                        label: "Last Workout",
                        value: formatDate(lastWorkout)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK lb", volume / 1000)
        }
        return "\(Int(volume)) lb"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Summary Row

struct SummaryRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(highlight ? .bold : .regular)
                .foregroundColor(highlight ? .green : .white)
        }
    }
}

// MARK: - Empty States

struct EmptyProgressionMessage: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("📊")
                .font(.system(.largeTitle))

            Text("Select an exercise to view progression")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct NoDataMessage: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("💪")
                .font(.system(.largeTitle))

            Text("Complete your first workout to see analytics")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
