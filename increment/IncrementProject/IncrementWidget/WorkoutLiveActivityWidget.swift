import ActivityKit
import WidgetKit
import SwiftUI
import IncrementFeature

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
            // Lock Screen UI
            WorkoutLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region (when tapped)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.currentExercise)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text("Set \(context.state.currentSet)/\(context.state.totalSets)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let restTime = context.state.restTimeRemaining, context.state.isResting {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatTime(restTime))
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                            Text("Rest")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Next prescription
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next Set")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("\(context.state.nextReps)")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.semibold)
                                Text("×")
                                    .foregroundStyle(.secondary)
                                Text("\(Int(context.state.nextWeight))")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.semibold)
                                Text("lb")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Progress indicator
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Progress")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("\(context.state.exercisesCompleted)/\(context.state.totalExercises)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                // Compact leading (small pill left side)
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption)
                    Text("INC")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                }
                .foregroundStyle(.blue)
            } compactTrailing: {
                // Compact trailing (small pill right side)
                if let restTime = context.state.restTimeRemaining, context.state.isResting {
                    Text(formatTime(restTime))
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                } else {
                    Text("\(context.state.currentSet)/\(context.state.totalSets)")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            } minimal: {
                // Minimal view (when multiple activities)
                if context.state.isResting {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutLiveActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Text(context.attributes.workoutName)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                Text("\(context.state.exercisesCompleted)/\(context.state.totalExercises)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // Current exercise and set
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.currentExercise)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Rest timer or ready state
                if let restTime = context.state.restTimeRemaining, context.state.isResting {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTime(restTime))
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                        Text("Rest")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Next prescription
            HStack {
                Text("Next:")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("\(context.state.nextReps)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                    Text("reps ×")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(Int(context.state.nextWeight))")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                    Text("lb")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(12)
        .activityBackgroundTint(Color.blue.opacity(0.1))
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}
