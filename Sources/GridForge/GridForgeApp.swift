import AppKit
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
        Window("Preferences", id: "prefs") {
            PreferencesView()
                .environmentObject(appState)
                .onAppear {
                    // Show in Cmd+Tab while Preferences are open.
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onDisappear {
                    NSApp.setActivationPolicy(.accessory)
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 640, height: 420)
        Window("About GridForge", id: "about") {
            AboutView()
                .environmentObject(updateChecker)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
