import SwiftUI
import HorizonCalendar

// MARK: - Calendar View

@MainActor
struct CalendarView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var currentMonth: Date = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Month Navigation
                MonthNavigator(currentMonth: $currentMonth)

                // Calendar Heatmap (HorizonCalendar)
                WorkoutCalendarView(
                    currentMonth: currentMonth,
                    heatmapData: sessionManager.workoutHeatmap(forMonth: currentMonth),
                    onMonthChange: { newMonth in
                        currentMonth = newMonth
                    }
                )
                .frame(height: 320)

                // Month Summary
                MonthSummary(
                    month: currentMonth,
                    sessions: sessionManager.sessions(forMonth: currentMonth)
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(24)
        }
    }
}

// MARK: - Month Navigator

struct MonthNavigator: View {
    @Binding var currentMonth: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CALENDAR")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Text("←")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Text("→")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1.0)
            }
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth).uppercased()
    }

    private var isCurrentMonth: Bool {
        let calendar = Calendar.current
        return calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    private func changeMonth(by value: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }
}

// MARK: - Workout Calendar View (HorizonCalendar)

struct WorkoutCalendarView: UIViewRepresentable {
    let currentMonth: Date
    let heatmapData: [Date: Double]
    let onMonthChange: (Date) -> Void

    private let calendar = Calendar.current

    func makeUIView(context: Context) -> HorizonCalendar.CalendarView {
        let calendarView = HorizonCalendar.CalendarView(initialContent: makeContent())

        // Configure appearance
        calendarView.backgroundColor = UIColor(white: 1.0, alpha: 0.03)
        calendarView.layer.cornerRadius = 4
        calendarView.layer.borderWidth = 1
        calendarView.layer.borderColor = UIColor(white: 1.0, alpha: 0.15).cgColor

        return calendarView
    }

    func updateUIView(_ uiView: HorizonCalendar.CalendarView, context: Context) {
        uiView.setContent(makeContent())
    }

    private func makeContent() -> CalendarViewContent {
        let maxVolume = heatmapData.values.max() ?? 1.0

        return CalendarViewContent(
            calendar: calendar,
            visibleDateRange: visibleDateRange,
            monthsLayout: .vertical(options: VerticalMonthsLayoutOptions())
        )
        .dayItemProvider { [heatmapData, calendar] day in
            let date = calendar.date(from: day.components)!
            let dayStart = calendar.startOfDay(for: date)
            let volume = heatmapData[dayStart] ?? 0.0
            let isToday = calendar.isDateInToday(date)

            return DayView.calendarItemModel(
                dayNumber: day.day,
                volume: volume,
                maxVolume: maxVolume,
                isToday: isToday
            )
        }
    }

    private var visibleDateRange: ClosedRange<Date> {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return currentMonth...currentMonth
        }
        return monthInterval.start...monthInterval.end
    }
}

// MARK: - Custom Day View

final class DayView: UIView {
    private let label = UILabel()

    fileprivate init() {
        super.init(frame: .zero)
        label.textAlignment = .center
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
    }

    fileprivate func configure(dayNumber: Int, volume: Double, maxVolume: Double, isToday: Bool) {
        label.text = "\(dayNumber)"
        label.font = UIFont.monospacedSystemFont(
            ofSize: 12,
            weight: isToday ? .bold : .regular
        )
        label.textColor = .white

        // Background color based on volume
        backgroundColor = Self.backgroundColor(
            volume: volume,
            maxVolume: maxVolume
        )

        layer.cornerRadius = 4

        // Today indicator
        if isToday {
            layer.borderWidth = 2
            layer.borderColor = UIColor(white: 1.0, alpha: 0.5).cgColor
        } else {
            layer.borderWidth = 0
        }
    }

    static func calendarItemModel(
        dayNumber: Int,
        volume: Double,
        maxVolume: Double,
        isToday: Bool
    ) -> CalendarItemModel<DayView> {
        CalendarItemModel<DayView>(
            invariantViewProperties: .init(
                dayNumber: dayNumber,
                volume: volume,
                maxVolume: maxVolume,
                isToday: isToday
            ),
            viewModel: .init()
        )
    }

    private static func backgroundColor(volume: Double, maxVolume: Double) -> UIColor {
        if volume == 0 {
            return UIColor(white: 1.0, alpha: 0.05)
        }

        let intensity = min(volume / maxVolume, 1.0)

        // Gradient from low (blue) to high (green)
        if intensity < 0.33 {
            return UIColor(red: 0, green: 0, blue: 1, alpha: 0.3 + intensity * 0.5)
        } else if intensity < 0.66 {
            return UIColor(red: 0, green: 1, blue: 1, alpha: 0.4 + intensity * 0.4)
        } else {
            return UIColor(red: 0, green: 1, blue: 0, alpha: 0.5 + intensity * 0.4)
        }
    }
}

// MARK: - CalendarItemViewRepresentable Conformance

extension DayView: CalendarItemViewRepresentable {
    struct InvariantViewProperties: Hashable {
        let dayNumber: Int
        let volume: Double
        let maxVolume: Double
        let isToday: Bool
    }

    struct ViewModel: Equatable {}

    typealias ViewType = DayView

    nonisolated static func makeView(withInvariantViewProperties invariantViewProperties: InvariantViewProperties) -> DayView {
        MainActor.assumeIsolated {
            let view = DayView()
            view.configure(
                dayNumber: invariantViewProperties.dayNumber,
                volume: invariantViewProperties.volume,
                maxVolume: invariantViewProperties.maxVolume,
                isToday: invariantViewProperties.isToday
            )
            return view
        }
    }

    nonisolated static func setViewModel(_ viewModel: ViewModel, on view: DayView) {
        // All content is set via invariantViewProperties in makeView
    }
}

// MARK: - Month Summary

struct MonthSummary: View {
    let month: Date
    let sessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MONTH SUMMARY")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Sessions",
                    value: "\(sessions.count)"
                )

                StatCard(
                    title: "Total Volume",
                    value: formatVolume(totalVolume)
                )

                StatCard(
                    title: "Avg/Week",
                    value: String(format: "%.1f", sessionsPerWeek)
                )

                StatCard(
                    title: "Longest Streak",
                    value: "\(longestStreak) days"
                )
            }
        }
    }

    private var totalVolume: Double {
        sessions.reduce(0.0) { $0 + $1.stats.totalVolume }
    }

    private var sessionsPerWeek: Double {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            return 0.0
        }

        let days = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 30
        let weeks = Double(days) / 7.0

        return Double(sessions.count) / weeks
    }

    private var longestStreak: Int {
        guard !sessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedDates = sessions
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()

        var currentStreak = 1
        var maxStreak = 1

        for i in 1..<sortedDates.count {
            let previousDate = sortedDates[i - 1]
            let currentDate = sortedDates[i]

            if let daysBetween = calendar.dateComponents([.day], from: previousDate, to: currentDate).day {
                if daysBetween == 1 {
                    currentStreak += 1
                    maxStreak = max(maxStreak, currentStreak)
                } else {
                    currentStreak = 1
                }
            }
        }

        return maxStreak
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK lb", volume / 1000)
        }
        return "\(Int(volume)) lb"
    }
}
