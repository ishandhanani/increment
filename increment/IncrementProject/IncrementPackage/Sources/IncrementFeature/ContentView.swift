import SwiftUI

@MainActor
public struct ContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var showingAnalytics = false
    @State private var showingSettings = false
    @State private var showingCalibration = false

    public init() {}

    public var body: some View {
        ZStack {
            // Terminal-style background
            IncrementTheme.backgroundGradient
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
        #if os(iOS)
        .fullScreenCover(isPresented: $showingCalibration) {
            CalibrationView(isPresented: $showingCalibration)
                .environment(sessionManager)
        }
        #else
        .sheet(isPresented: $showingCalibration) {
            CalibrationView(isPresented: $showingCalibration)
                .environment(sessionManager)
        }
        #endif
        .onAppear {
            checkCalibrationStatus()
        }
    }

    private func checkCalibrationStatus() {
        // Only show calibration on first launch (intro screen + no calibration done)
        if sessionManager.sessionState == .intro && !PersistenceManager.shared.hasCompletedCalibration() {
            showingCalibration = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(SessionManager())
    }
}
