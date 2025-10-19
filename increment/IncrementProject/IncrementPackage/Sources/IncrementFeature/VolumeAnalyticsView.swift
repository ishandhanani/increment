import SwiftUI
import Charts

// MARK: - Volume Analytics View

@MainActor
struct VolumeAnalyticsView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var selectedDateRange: DateRange = .last30Days

    enum DateRange: String, CaseIterable {
        case last7Days = "7 DAYS"
        case last30Days = "30 DAYS"
        case last90Days = "90 DAYS"
        case allTime = "ALL TIME"

        var days: Int? {
            switch self {
            case .last7Days: return 7
            case .last30Days: return 30
            case .last90Days: return 90
            case .allTime: return nil
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Date Range Filter
                DateRangeSelector(selectedRange: $selectedDateRange)

                // Volume by Session Chart
                VolumeBySessionChart(
                    sessions: filteredSessions,
                    dateRange: selectedDateRange
                )

                // Category Breakdown
                if !sessionManager.volumeByCategory.isEmpty {
                    CategoryBreakdownSection(
                        volumeByCategory: sessionManager.volumeByCategory
                    )
                }

                // Volume Stats
                VolumeStatsGrid(sessions: filteredSessions)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(24)
        }
    }

    private var filteredSessions: [Session] {
        guard let days = selectedDateRange.days else {
            return sessionManager.allSessions
        }

        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        return sessionManager.allSessions.filter { $0.date >= cutoffDate }
    }
}

// MARK: - Date Range Selector

struct DateRangeSelector: View {
    @Binding var selectedRange: VolumeAnalyticsView.DateRange

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME RANGE")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 8) {
                ForEach(VolumeAnalyticsView.DateRange.allCases, id: \.self) { range in
                    Button {
                        selectedRange = range
                    } label: {
                        Text(range.rawValue)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(selectedRange == range ? .bold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedRange == range
                                    ? Color.white.opacity(0.15)
                                    : Color.white.opacity(0.05)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Volume by Session Chart

struct VolumeBySessionChart: View {
    let sessions: [Session]
    let dateRange: VolumeAnalyticsView.DateRange
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("VOLUME PER SESSION")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)

            if sessions.isEmpty {
                EmptyChartMessage(message: "No sessions in this time range")
            } else {
                let sortedSessions = sessions.sorted { $0.date < $1.date }
                let maxVolume = sortedSessions.map { $0.stats.totalVolume }.max() ?? 1.0

                Chart(sortedSessions) { session in
                    BarMark(
                        x: .value("Date", session.date, unit: .day),
                        y: .value("Volume", session.stats.totalVolume)
                    )
                    .foregroundStyle(
                        selectedDate != nil && Calendar.current.isDate(session.date, inSameDayAs: selectedDate!)
                            ? LinearGradient(
                                colors: [.green.opacity(0.9), .green.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [.white.opacity(0.8), .white.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .cornerRadius(2)

                    // Average line annotation
                    if let avgVolume = calculateAverage(sessions: sortedSessions) {
                        RuleMark(y: .value("Average", avgVolume))
                            .foregroundStyle(.yellow.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("AVG")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.yellow.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(3)
                            }
                    }

                    // Selection indicator
                    if let selectedDate = selectedDate,
                       Calendar.current.isDate(session.date, inSameDayAs: selectedDate) {
                        PointMark(
                            x: .value("Date", session.date, unit: .day),
                            y: .value("Volume", session.stats.totalVolume)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(100)
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let volume = value.as(Double.self) {
                                Text(formatVolume(volume))
                                    .font(.system(.caption2, design: .monospaced))
                            }
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(height: 240)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

                // Selection details
                if let selectedDate = selectedDate,
                   let selectedSession = sortedSessions.first(where: {
                       Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
                   }) {
                    SessionDetailCard(session: selectedSession)
                }
            }
        }
    }

    private func calculateAverage(sessions: [Session]) -> Double? {
        guard !sessions.isEmpty else { return nil }
        let total = sessions.reduce(0.0) { $0 + $1.stats.totalVolume }
        return total / Double(sessions.count)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK", volume / 1000)
        }
        return "\(Int(volume))"
    }
}

// MARK: - Session Detail Card

struct SessionDetailCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SESSION DETAILS")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.green)

                Spacer()

                Text(formatDate(session.date))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            Divider()
                .background(Color.white.opacity(0.2))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Volume")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                    Text(formatVolume(session.stats.totalVolume))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Exercises")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(session.exerciseLogs.count)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Spacer()

                if let feeling = session.preWorkoutFeeling {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Feeling")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(feeling.rating)/5")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
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
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Category Breakdown Section

struct CategoryBreakdownSection: View {
    let volumeByCategory: [VolumeByCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CATEGORY BREAKDOWN")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(volumeByCategory, id: \.category) { item in
                    CategoryBar(item: item)
                }
            }
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

// MARK: - Category Bar

struct CategoryBar: View {
    let item: VolumeByCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.category.rawValue.uppercased())
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Text("\(Int(item.percentage))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))

                Text("•")
                    .foregroundColor(.white.opacity(0.3))

                Text(formatVolume(item.volume))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                        .cornerRadius(3)

                    // Progress
                    Rectangle()
                        .fill(colorForCategory(item.category))
                        .frame(width: geometry.size.width * (item.percentage / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }

    private func colorForCategory(_ category: ExerciseCategory) -> Color {
        switch category {
        case .barbell:
            return .blue.opacity(0.8)
        case .dumbbell:
            return .purple.opacity(0.8)
        case .machine:
            return .green.opacity(0.8)
        case .bodyweight:
            return .cyan.opacity(0.8)
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK lb", volume / 1000)
        }
        return "\(Int(volume)) lb"
    }
}

// MARK: - Volume Stats Grid

struct VolumeStatsGrid: View {
    let sessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STATS")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Total Volume",
                    value: formatVolume(totalVolume)
                )

                StatCard(
                    title: "Avg/Session",
                    value: formatVolume(avgVolumePerSession)
                )

                StatCard(
                    title: "Sessions",
                    value: "\(sessions.count)"
                )

                StatCard(
                    title: "Best Session",
                    value: formatVolume(bestSession)
                )
            }
        }
    }

    private var totalVolume: Double {
        sessions.reduce(0.0) { $0 + $1.stats.totalVolume }
    }

    private var avgVolumePerSession: Double {
        guard !sessions.isEmpty else { return 0.0 }
        return totalVolume / Double(sessions.count)
    }

    private var bestSession: Double {
        sessions.map { $0.stats.totalVolume }.max() ?? 0.0
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK lb", volume / 1000)
        }
        return "\(Int(volume)) lb"
    }
}

// MARK: - Empty Chart Message

struct EmptyChartMessage: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text("📊")
                .font(.system(.largeTitle))

            Text(message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
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
