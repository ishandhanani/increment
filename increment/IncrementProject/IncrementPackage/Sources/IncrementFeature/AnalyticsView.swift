import SwiftUI
import Charts

// MARK: - Analytics Navigation Container

@MainActor
public struct AnalyticsView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Binding var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    isPresented = false
                } label: {
                    HStack(spacing: 6) {
                        Text("←")
                            .font(.system(.body, design: .monospaced))
                        Text("Back")
                            .font(.system(.body, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Analytics")
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color.black.opacity(0.3))

            // Analytics content
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Quick Stats Grid
                    QuickStatsGrid(stats: sessionManager.overviewStats)

                    // Recent Trend Chart
                    if !sessionManager.overviewStats.recentTrend.isEmpty {
                        RecentTrendChart(trend: sessionManager.overviewStats.recentTrend)
                    }

                    // Insights Section
                    if !sessionManager.performanceInsights.isEmpty {
                        InsightsSection(insights: sessionManager.performanceInsights)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(24)
            }

            Spacer()
        }
    }
}

// MARK: - Analytics Tabs

enum AnalyticsTab {
    case overview
    case exercises
}

// MARK: - Tab Button Component

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .monospaced))
                .fontWeight(isSelected ? .bold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(isSelected ? .white : .clear),
                    alignment: .bottom
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overview Dashboard View

@MainActor
struct OverviewDashboardView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Quick Stats Grid
                QuickStatsGrid(stats: sessionManager.overviewStats)

                // Recent Trend Chart
                if !sessionManager.overviewStats.recentTrend.isEmpty {
                    RecentTrendChart(trend: sessionManager.overviewStats.recentTrend)
                }

                // Insights Section
                if !sessionManager.performanceInsights.isEmpty {
                    InsightsSection(insights: sessionManager.performanceInsights)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(24)
        }
    }
}

// MARK: - Quick Stats Grid

struct QuickStatsGrid: View {
    let stats: OverviewStats

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Sessions",
                    value: "\(stats.totalSessions)"
                )

                StatCard(
                    title: "Volume",
                    value: formatVolume(stats.totalVolume)
                )

                StatCard(
                    title: "Streak",
                    value: "\(stats.currentStreak) days"
                )

                StatCard(
                    title: "Avg lift",
                    value: "\(Int(stats.averageLift)) lb"
                )
            }
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK lb", volume / 1000)
        }
        return "\(Int(volume)) lb"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Recent Trend Chart

struct RecentTrendChart: View {
    let trend: [VolumeDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Volume trend (30 days)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)

            Chart(trend) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Volume", dataPoint.volume)
                )
                .foregroundStyle(.white)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Volume", dataPoint.volume)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.4))
                        .font(.system(.caption2, design: .monospaced))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.4))
                        .font(.system(.caption2, design: .monospaced))
                }
            }
            .frame(height: 180)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: - Insights Section

struct InsightsSection: View {
    let insights: [PerformanceInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)

            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: PerformanceInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // Indicator dot
                Circle()
                    .fill(colorForInsightType(insight.type))
                    .frame(width: 6, height: 6)

                Text(insight.title)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()
            }

            Text(insight.message)
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func colorForInsightType(_ type: InsightType) -> Color {
        switch type {
        case .feelingCorrelation:
            return .blue
        case .consistencyPattern:
            return .green
        case .challengingExercise:
            return .orange
        case .bestPerforming:
            return .yellow
        case .streakAchievement:
            return .purple
        }
    }
}

