import SwiftUI
import SwiftData
import IncrementFeature

@main
struct IncrementApp: App {
    @State private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionManager)
        }
        .modelContainer(for: [Session.self, ExerciseSessionLog.self, SetLog.self])
    }
}

/// Root view that injects ModelContext into SessionManager
struct RootView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentView()
            .onAppear {
                // Inject ModelContext on first appear
                if sessionManager.modelContext == nil {
                    sessionManager.modelContext = modelContext
                }
            }
    }
}