import SwiftUI

@main
struct GridForgeApp: App {
    @StateObject private var appState      = AppState.shared
    @StateObject private var updateChecker = UpdateChecker()

    var body: some Scene {
        MenuBarExtra("GridForge", systemImage: "grid") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(updateChecker)
                .onAppear {
                    // One-shot update check; guarded inside checkInBackground().
                    // Task.detached ensures it survives menu close.
                    updateChecker.checkInBackground()
                }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }

        Window("About GridForge", id: "about") {
            AboutView()
                .environmentObject(updateChecker)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
