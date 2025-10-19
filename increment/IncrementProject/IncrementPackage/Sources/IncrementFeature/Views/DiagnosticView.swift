import SwiftUI

@MainActor
public struct DiagnosticView: View {
    @Binding var isPresented: Bool
    @State private var diagnostic: DiagnosticResult?
    @State private var isLoading = true

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack {
            // Background
            IncrementTheme.backgroundGradient
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
            } else if let diagnostic = diagnostic {
                DiagnosticContent(diagnostic: diagnostic, isPresented: $isPresented)
            } else {
                EmptyDiagnosticView(isPresented: $isPresented)
            }
        }
        .task {
            await loadDiagnostic()
        }
    }

    private func loadDiagnostic() async {
        isLoading = true

        // Load all sessions
        let sessions = PersistenceManager.shared.loadSessionsSync()

        // Compute diagnostic
        let result = DiagnosticEngine.computeMonthlyDiagnostic(sessions: sessions)

        diagnostic = result
        isLoading = false
    }
}

// MARK: - Diagnostic Content

private struct DiagnosticContent: View {
    let diagnostic: DiagnosticResult
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("═══════════════════════════════════════")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.5))

                    Text("MONTHLY CHECK-IN")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)

                    Text(formatDateRange(start: diagnostic.periodStart, end: diagnostic.periodEnd))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))

                    Text("═══════════════════════════════════════")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.5))
                }
                .padding(.top, 40)
                .padding(.bottom, 32)

                // Metrics
                VStack(spacing: 32) {
                    // Metric 1: Progress
                    MetricCard(
                        title: "PROGRESS",
                        value: formatWeight(diagnostic.averageWeightGain),
                        subtitle: "avg across all lifts",
                        status: progressStatus(diagnostic.averageWeightGain),
                        icon: progressIcon(diagnostic.averageWeightGain)
                    )

                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 24)

                    // Metric 2: Bad Days
                    MetricCard(
                        title: "BAD DAYS",
                        value: "\(Int(diagnostic.badDayFrequency))%",
                        subtitle: "\(badDayCount(diagnostic)) of \(diagnostic.totalSessions) sessions",
                        status: badDayStatus(diagnostic.badDayFrequency),
                        icon: badDayIcon(diagnostic.badDayFrequency)
                    )

                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 24)

                    // Metric 3: Stalled Lifts
                    StalledLiftsSection(lifts: diagnostic.stalledLifts)
                }
                .padding(.horizontal, 24)

                // Close Button
                Button {
                    isPresented = false
                } label: {
                    Text("CLOSE")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.cyan)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
        }
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight > 0 {
            return "+\(String(format: "%.1f", weight)) lbs"
        } else if weight < 0 {
            return "\(String(format: "%.1f", weight)) lbs"
        } else {
            return "0 lbs"
        }
    }

    private func progressStatus(_ weight: Double) -> String {
        if weight > 5 {
            return "EXCELLENT"
        } else if weight > 0 {
            return "GOOD"
        } else if weight == 0 {
            return "STAGNANT"
        } else {
            return "DECLINING"
        }
    }

    private func progressIcon(_ weight: Double) -> String {
        if weight > 0 {
            return "✓"
        } else {
            return "⚠"
        }
    }

    private func badDayCount(_ diagnostic: DiagnosticResult) -> Int {
        Int((diagnostic.badDayFrequency / 100.0) * Double(diagnostic.totalSessions))
    }

    private func badDayStatus(_ frequency: Double) -> String {
        if frequency < 15 {
            return "NORMAL"
        } else if frequency < 30 {
            return "ELEVATED"
        } else {
            return "HIGH"
        }
    }

    private func badDayIcon(_ frequency: Double) -> String {
        if frequency < 20 {
            return "✓"
        } else {
            return "⚠"
        }
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let status: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)

            // Value
            Text(value)
                .font(.system(.largeTitle, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Subtitle
            Text(subtitle)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

            // Status
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(statusColor(status))

                Text(status)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(statusColor(status))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(statusColor(status).opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(statusColor(status).opacity(0.3), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "EXCELLENT", "GOOD", "NORMAL":
            return .cyan
        case "ELEVATED", "STAGNANT":
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - Stalled Lifts Section

private struct StalledLiftsSection: View {
    let lifts: [StalledLift]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text("STALLED LIFTS")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)

            if lifts.isEmpty {
                // No stalled lifts
                HStack {
                    Text("✓")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text("All lifts progressing")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
            } else {
                // List stalled lifts
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(lifts, id: \.exerciseId) { lift in
                        HStack {
                            Text("→")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.yellow)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(lift.exerciseName)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)

                                Text("\(lift.weeksStalled) week\(lift.weeksStalled > 1 ? "s" : "") no progress")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()
                        }

                        if lift.exerciseId != lifts.last?.exerciseId {
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty State

private struct EmptyDiagnosticView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text("NOT ENOUGH DATA")
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.7))

            Text("Complete at least one workout to\ngenerate your diagnostic.")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button {
                isPresented = false
            } label: {
                Text("CLOSE")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(width: 200)
                    .frame(height: 54)
                    .background(Color.cyan)
                    .cornerRadius(8)
            }
            .padding(.top, 16)
        }
    }
}
