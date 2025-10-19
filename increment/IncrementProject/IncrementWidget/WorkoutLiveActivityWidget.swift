import ActivityKit
import WidgetKit
import SwiftUI
import IncrementFeature

// MARK: - Time Formatting Utility
private func formatTime(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
    if mins > 0 {
        return String(format: "%d:%02d", mins, secs)
    } else {
        return String(format: "%ds", secs)
    }
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
            // Lock Screen UI
            WorkoutLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region (when tapped)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.currentExercise)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        Text("Set: \(context.state.currentSet)/\(context.state.totalSets)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let restTime = context.state.restTimeRemaining, context.state.isResting {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatTime(restTime))
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                            Text("REST")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("ACTIVE")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                            Text("\(context.state.exercisesCompleted)/\(context.state.totalExercises)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Next prescription
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEXT")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 2) {
                                Text("\(context.state.nextReps)")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.bold)
                                Text("×")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text("\(Int(context.state.nextWeight))")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .fontWeight(.bold)
                                Text("lb")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Workout progress
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("EXERCISES")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("\(context.state.exercisesCompleted)/\(context.state.totalExercises)")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            } compactLeading: {
                // Compact leading (small pill left side)
                HStack(spacing: 2) {
                    Text("•")
                        .font(.system(.caption2, design: .monospaced))
                        .fontWeight(.bold)
                    Text("INC")
                        .font(.system(.caption2, design: .monospaced))
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
            } compactTrailing: {
                // Compact trailing (small pill right side)
                if let restTime = context.state.restTimeRemaining, context.state.isResting {
                    Text(formatTime(restTime))
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                } else {
                    Text("\(context.state.currentSet)/\(context.state.totalSets)")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            } minimal: {
                // Minimal view (when multiple activities)
                Text("•")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(context.state.isResting ? .orange : .white)
            }
        }
    }
}

struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutLiveActivityAttributes>

    var body: some View {
        VStack(spacing: 10) {
            // Header - exercise name and progress
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.currentExercise)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        Text("Set:")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(context.state.currentSet)/\(context.state.totalSets)")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }

                Spacer()

                // Status indicator
                if let restTime = context.state.restTimeRemaining, context.state.isResting {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTime(restTime))
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                        Text("REST")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ACTIVE")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("\(context.state.exercisesCompleted)/\(context.state.totalExercises)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(height: 1)

            // Next prescription - always visible
            HStack(spacing: 6) {
                Text("NEXT:")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                HStack(spacing: 3) {
                    Text("\(context.state.nextReps)")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                    Text("×")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(Int(context.state.nextWeight))")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.bold)
                    Text("lb")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(14)
        .activityBackgroundTint(Color(red: 0.1, green: 0.15, blue: 0.3).opacity(0.8))
    }
}
