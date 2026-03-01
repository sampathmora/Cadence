import SwiftUI

@main
struct CadenceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(HealthViewModel())  // Shared across all tabs
        }
    }
}
