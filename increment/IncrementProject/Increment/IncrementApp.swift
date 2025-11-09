import SwiftUI
import IncrementFeature

@main
struct IncrementApp: App {
    @State private var sessionManager = SessionManager()
    @State private var userSettings = UserSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionManager)
                .environment(userSettings)
                .task {
                    await sessionManager.initialize()
                }
        }
    }
}