import SwiftUI
import GridForgeCore

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Activate Grid  ⌘⇧G") {
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
        Divider()
        Button("Quit GridForge") { NSApplication.shared.terminate(nil) }
    }
}
