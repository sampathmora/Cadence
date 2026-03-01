import SwiftUI

struct ContentView: View {
    @Environment(HealthViewModel.self) var vm

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "heart.fill") }
            StepsView()
                .tabItem { Label("Steps", systemImage: "figure.walk") }
            ZonesView()
                .tabItem { Label("Zones", systemImage: "waveform.path.ecg") }
        }
        .task { await vm.onAppear() }  // Single auth trigger for entire app
    }
}
