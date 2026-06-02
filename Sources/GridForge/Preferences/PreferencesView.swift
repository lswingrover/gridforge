import SwiftUI
import GridForgeCore

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = PrefsTab.grid

    enum PrefsTab: String, CaseIterable {
        case grid      = "Grid"
        case shortcuts = "Shortcuts"
        case layouts   = "Layouts"
        case rules     = "Per-App Rules"
        case advanced  = "Advanced"

        var icon: String {
            switch self {
            case .grid:      return "grid"
            case .shortcuts: return "keyboard"
            case .layouts:   return "rectangle.3.group"
            case .rules:     return "app.badge"
            case .advanced:  return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(PrefsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 140, ideal: 160)
        } detail: {
            Group {
                switch selectedTab {
                case .grid:      GridPrefsView()
                case .shortcuts: ShortcutsPrefsView()
                case .layouts:   LayoutsPrefsView()
                case .rules:     PerAppRulesPrefsView()
                case .advanced:  AdvancedPrefsView()
                }
            }
            .frame(minWidth: 460, minHeight: 360)
            .padding()
        }
        .frame(width: 640, height: 420)
    }
}

// MARK: - Grid Preferences

struct GridPrefsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDisplayIndex = 0
    @State private var columns: Int = 6
    @State private var rows:    Int = 4
    @State private var gap:     Double = 0

    private var displays: [(id: String, name: String)] {
        appState.displayManager.allDisplayProfiles
    }

    var body: some View {
        Form {
            Picker("Display", selection: $selectedDisplayIndex) {
                ForEach(displays.indices, id: \.self) { i in
                    Text(displays[i].name).tag(i)
                }
            }
            .onChange(of: selectedDisplayIndex) { loadConfig() }

            Divider()

            Stepper("Columns: \(columns)", value: $columns, in: 1...20)
            Stepper("Rows: \(rows)",       value: $rows,    in: 1...20)

            HStack {
                Text("Gap")
                Slider(value: $gap, in: 0...20, step: 1)
                Text("\(Int(gap)) px").frame(width: 40, alignment: .trailing)
            }

            Divider()

            GridPreviewView(columns: columns, rows: rows)
                .frame(height: 120)
                .cornerRadius(8)

        }
        .onAppear { loadConfig() }
        .onChange(of: columns) { saveConfig() }
        .onChange(of: rows)    { saveConfig() }
        .onChange(of: gap)     { saveConfig() }
        .formStyle(.grouped)
    }

    private func currentDisplayID() -> String {
        guard selectedDisplayIndex < displays.count else { return "display_main" }
        return displays[selectedDisplayIndex].id
    }

    private func loadConfig() {
        let cfg  = DatabaseManager.shared.loadGridConfig(displayID: currentDisplayID())
        columns  = cfg.columns
        rows     = cfg.rows
        gap      = Double(cfg.gapPixels)
    }

    private func saveConfig() {
        let cfg = GridConfig(columns: columns, rows: rows, gapPixels: CGFloat(gap))
        DatabaseManager.shared.saveGridConfig(cfg, displayID: currentDisplayID())
    }
}

// MARK: - Grid Preview

struct GridPreviewView: View {
    let columns: Int
    let rows:    Int

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.15)))
            let cw = size.width  / CGFloat(columns)
            let ch = size.height / CGFloat(rows)
            var path = Path()
            for c in 1..<columns {
                path.move(to:    CGPoint(x: CGFloat(c) * cw, y: 0))
                path.addLine(to: CGPoint(x: CGFloat(c) * cw, y: size.height))
            }
            for r in 1..<rows {
                path.move(to:    CGPoint(x: 0,          y: CGFloat(r) * ch))
                path.addLine(to: CGPoint(x: size.width, y: CGFloat(r) * ch))
            }
            context.stroke(path, with: .color(.secondary.opacity(0.6)), lineWidth: 0.5)
        }
        .background(Color.secondary.opacity(0.1))
    }
}

// MARK: - Shortcuts Preferences (stub — Phase 2)

struct ShortcutsPrefsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts").font(.headline)
            Text("Map any key combo to a saved grid position.\nFull shortcut editor coming in v1.1.")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Layouts Preferences

struct LayoutsPrefsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Named Layouts").font(.headline)

            Table(appState.layouts) {
                TableColumn("Name",   value: \.name)
                TableColumn("Hotkey") { layout in
                    Text(layout.hotkey ?? "—").foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 140)

            HStack {
                TextField("New layout name…", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button("Save Current") {
                    guard !newName.isEmpty else { return }
                    appState.saveCurrentAsLayout(name: newName)
                    newName = ""
                }
                .disabled(newName.isEmpty)
            }
        }
    }
}

// MARK: - Per-App Rules (stub — Phase 4)

struct PerAppRulesPrefsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-App Rules").font(.headline)
            Text("Automatically snap apps to a grid position on launch or focus.\nComing in v1.1.")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Advanced Preferences

struct AdvancedPrefsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Accessibility") {
                HStack {
                    Image(systemName: appState.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(appState.accessibilityGranted ? .green : .orange)
                    Text(appState.accessibilityGranted ? "Accessibility access granted" : "Accessibility access required")
                    if !appState.accessibilityGranted {
                        Spacer()
                        Button("Grant Access") {
                            appState.windowManager.requestAccessibilityPermission()
                        }
                    }
                }
            }

            Section("Hotkey") {
                Text("Default: ⌘⇧G — customisable hotkey editor in v1.1")
                    .foregroundStyle(.secondary)
            }

            Section("Companion API") {
                Text("Local API server on port 14731\nEvery UI action is reachable via Claude, other AI, SDK, or API.")
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                HStack {
                    Text("GridForge")
                    Spacer()
                    Text("v1.0.0").foregroundStyle(.secondary)
                }
                Link("View on GitHub",
                     destination: URL(string: "https://github.com/lswingrover/gridforge")!)
            }
        }
        .formStyle(.grouped)
    }
}
