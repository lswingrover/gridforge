import SwiftUI

@main
struct GridForgeApp: App {

    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("GridForge", systemImage: "grid") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}
