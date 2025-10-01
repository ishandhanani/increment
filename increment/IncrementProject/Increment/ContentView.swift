import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        ZStack {
            // Terminal-style background
            Color(red: 0.1, green: 0.15, blue: 0.3)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Render appropriate view based on session state
                switch sessionManager.sessionState {
                case .intro:
                    IntroView()
                case .preWorkout:
                    PreWorkoutView()
                case .stretching(_):
                    StretchingView()
                case .warmup(_):
                    WarmupView()
                case .load:
                    LoadView()
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
        .font(.system(.body, design: .monospaced))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(SessionManager())
    }
}
