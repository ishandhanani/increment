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
            // Header with back button - matches ExerciseHeader pattern
            HStack {
                Button {
                    isPresented = false
                } label: {
                    HStack(spacing: 8) {
                        Text("←")
                        Text("BACK")
                    }
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("ANALYTICS")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .foregroundColor(.white)
            .padding(16)
            .background(Color.black.opacity(0.3))

            // Analytics content
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
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK STATS")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "SESSIONS",
                    value: "\(stats.totalSessions)",
                    icon: "📊"
                )

                StatCard(
                    title: "VOLUME",
                    value: formatVolume(stats.totalVolume),
                    icon: "💪"
                )

                StatCard(
                    title: "STREAK",
                    value: "\(stats.currentStreak) days",
                    icon: "🔥"
                )

                StatCard(
                    title: "AVG LIFT",
                    value: "\(Int(stats.averageLift)) lb",
                    icon: "⚖️"
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
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(icon)
                .font(.system(.title2))

            Text(value)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Recent Trend Chart

struct RecentTrendChart: View {
    let trend: [VolumeDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VOLUME TREND (30 DAYS)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            Chart(trend) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Volume", dataPoint.volume)
                )
                .foregroundStyle(.white)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Volume", dataPoint.volume)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
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
            .frame(height: 150)
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

// MARK: - Insights Section

struct InsightsSection: View {
    let insights: [PerformanceInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSIGHTS")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(iconForInsightType(insight.type))
                    .font(.system(.title3))

                Text(insight.title)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(insight.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func iconForInsightType(_ type: InsightType) -> String {
        switch type {
        case .feelingCorrelation:
            return "💡"
        case .consistencyPattern:
            return "✨"
        case .challengingExercise:
            return "💪"
        case .bestPerforming:
            return "🏆"
        case .streakAchievement:
            return "🔥"
        }
    }
}

