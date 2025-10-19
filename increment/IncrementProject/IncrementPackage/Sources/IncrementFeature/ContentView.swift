import SwiftUI

@MainActor
public struct ContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var showingAnalytics = false
    @State private var showingSettings = false

    public init() {}

    public var body: some View {
        ZStack {
            // Terminal-style background
            Color(red: 0.1, green: 0.15, blue: 0.3)
                .ignoresSafeArea()

            if showingSettings {
                // Settings View
                SettingsView(isPresented: $showingSettings)
            } else if showingAnalytics {
                // Analytics View
                AnalyticsView(isPresented: $showingAnalytics)
            } else {
                // Main Session Flow
                VStack(spacing: 0) {
                    // Render appropriate view based on session state
                    switch sessionManager.sessionState {
                    case .intro:
                        IntroView(showAnalytics: $showingAnalytics, showSettings: $showingSettings)
                    case .workoutSelection:
                        WorkoutSelectionView()
                    case .preWorkout:
                        PreWorkoutView()
                    case .workoutOverview:
                        WorkoutOverviewView()
                    case .stretching(_):
                        StretchingView()
                    case .warmup(_):
                        WarmupView()
                    case .workingSet:
                        WorkingSetView()
                    case .rest(_):
                        RestView()
                    case .review:
                        ReviewView()
                    case .done:
                        DoneView()
                    }
                }
            }
        }
        .font(.system(.body, design: .monospaced))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(SessionManager())
    }
}
