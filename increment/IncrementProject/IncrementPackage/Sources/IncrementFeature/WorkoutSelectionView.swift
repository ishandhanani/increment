import SwiftUI

public struct WorkoutSelectionView: View {
    @Environment(SessionManager.self) private var sessionManager

    private var suggestedType: LiftCategory {
        sessionManager.suggestedWorkoutType
    }

    private var template: WorkoutTemplate? {
        // Generate preview template for display
        WorkoutBuilder.build(type: suggestedType)
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

            ScrollView {
                VStack(spacing: 24) {
                    // Workout header
                    if let template = template {
                        VStack(alignment: .leading, spacing: 16) {
                            // Workout type
                            Text(template.name.uppercased())
                                .font(.system(.largeTitle, design: .monospaced))
                                .fontWeight(.bold)

                            // Workout details
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TYPE: \(template.workoutType.rawValue.uppercased())")
                                    .font(.system(.body, design: .monospaced))
                                    .opacity(0.7)

                                if !template.exercises.isEmpty {
                                    Text("EXERCISES: \(template.exercises.count)")
                                        .font(.system(.body, design: .monospaced))
                                        .opacity(0.7)
                                }

                                if let duration = template.estimatedDuration {
                                    let minutes = Int(duration / 60)
                                    Text("EST. TIME: \(minutes) MIN")
                                        .font(.system(.body, design: .monospaced))
                                        .opacity(0.7)
                                }
                            }

                            // Exercise list
                            if !template.exercises.isEmpty {
                                Divider()
                                    .background(Color.white.opacity(0.2))
                                    .padding(.vertical, 8)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("EXERCISES:")
                                        .font(.system(.callout, design: .monospaced))
                                        .fontWeight(.bold)
                                        .opacity(0.7)

                                    ForEach(template.exercises.sorted(by: { $0.order < $1.order }), id: \.lift.name) { exercise in
                                        HStack(spacing: 12) {
                                            Text("\(exercise.order).")
                                                .font(.system(.body, design: .monospaced))
                                                .opacity(0.5)
                                                .frame(width: 24, alignment: .trailing)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(exercise.lift.name)
                                                    .font(.system(.body, design: .monospaced))

                                                HStack(spacing: 12) {
                                                    Text("\(exercise.targetSets) sets")
                                                        .font(.system(.caption, design: .monospaced))
                                                        .opacity(0.6)

                                                    Text("•")
                                                        .opacity(0.4)

                                                    Text("\(exercise.lift.steelConfig.repRange.lowerBound)-\(exercise.lift.steelConfig.repRange.upperBound) reps")
                                                        .font(.system(.caption, design: .monospaced))
                                                        .opacity(0.6)

                                                    if exercise.priority == .core {
                                                        Text("•")
                                                            .opacity(0.4)

                                                        Text("CORE")
                                                            .font(.system(.caption, design: .monospaced))
                                                            .fontWeight(.bold)
                                                            .opacity(0.8)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                }
            }

            // Action Bar
            ActionBar {
                sessionManager.confirmWorkoutStart()
            } label: {
                Text("START WORKOUT")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.1, green: 0.15, blue: 0.3))
        .foregroundColor(.white)
    }
}
