import SwiftUI
import IncrementFeature

@main
struct IncrementApp: App {
    @State private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionManager)
        }
    }
}