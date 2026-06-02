import SwiftUI
import GridForgeCore

struct MenuBarView: View {
    @EnvironmentObject var appState:      AppState
    @EnvironmentObject var updateChecker: UpdateChecker
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow)   private var openWindow

    var body: some View {
        // Update banner (shown only when a newer release is available)
        if let info = updateChecker.updateInfo {
            Button("✨ GridForge \(info.tagName) available…") {
                updateChecker.openReleasePage()
            }
            Divider()
        }

        Button("Activate Grid  \(HotkeyManager.displayString(keyCode: appState.hotkeyCode, modifiers: appState.hotkeyModifiers))") {
            appState.activateGrid()
        }

        Divider()

        if !appState.layouts.isEmpty {
            Menu("Layouts") {
                ForEach(appState.layouts) { layout in
                    Button(layout.name) {
                        appState.applyLayout(layout)
                    }
                }
            }
            Divider()
        }

        if !appState.accessibilityGranted {
            Button("⚠️ Grant Accessibility Access…") {
                appState.windowManager.requestAccessibilityPermission()
            }
            Divider()
        }

        Button("Preferences…") { openSettings() }

        Button("About GridForge…") {
            // LSUIElement apps need explicit activation to bring windows forward.
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "about")
        }

        Divider()

        Button("Quit GridForge") { NSApplication.shared.terminate(nil) }
    }
}
