import SwiftUI
import GridForgeCore

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = PrefsTab.grid

    enum PrefsTab: String, CaseIterable {
        case grid      = "Grid"
        case shortcuts = "Shortcuts"
        case layouts   = "Layouts"
        case displays  = "Displays"
        case rules     = "Per-App Rules"
        case advanced  = "Advanced"

        var icon: String {
            switch self {
            case .grid:      return "grid"
            case .shortcuts: return "keyboard"
            case .layouts:   return "rectangle.3.group"
            case .displays:  return "display"
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
                case .displays:  DisplaysPrefsView()
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

// MARK: - Shortcuts Preferences (GH#1)

struct ShortcutsPrefsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Keyboard Shortcuts").font(.headline)
                Spacer()
                Button { showAddSheet = true } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            if appState.shortcuts.isEmpty {
                ContentUnavailableView(
                    "No shortcuts yet",
                    systemImage: "keyboard",
                    description: Text("Tap + to map a key combo to a grid region.")
                )
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Table(appState.shortcuts) {
                    TableColumn("Shortcut") { sc in
                        Text(HotkeyManager.displayString(forCombo: sc.keyCombo))
                            .font(.system(.body, design: .monospaced))
                    }
                    TableColumn("Region") { sc in
                        Text(sc.selection.encoded)
                            .foregroundStyle(.secondary)
                            .font(.system(.caption, design: .monospaced))
                    }
                    TableColumn("Name") { sc in
                        Text(sc.name ?? "—").foregroundStyle(.secondary)
                    }
                    TableColumn("") { sc in
                        Button {
                            appState.deleteShortcut(sc)
                        } label: {
                            Image(systemName: "trash").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .width(28)
                }
                .frame(minHeight: 120)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddShortcutSheet { sc in appState.addShortcut(sc) }
                .environmentObject(appState)
        }
    }
}

// MARK: - Add Shortcut Sheet

struct AddShortcutSheet: View {
    let onSave: (SavedShortcut) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name      = ""
    @State private var keyCode:   UInt16               = 18     // key 1
    @State private var modifiers: NSEvent.ModifierFlags = [.command]
    @State private var colStart  = 0
    @State private var rowStart  = 0
    @State private var colEnd    = 2
    @State private var rowEnd    = 2

    private var selection: GridSelection {
        GridSelection(
            startCell: GridCell(col: min(colStart, colEnd), row: min(rowStart, rowEnd)),
            endCell:   GridCell(col: max(colStart, colEnd), row: max(rowStart, rowEnd))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Shortcut").font(.headline).padding([.top, .horizontal])
            Form {
                Section("Key Combo") {
                    KeyRecorderView(keyCode: $keyCode, modifiers: $modifiers)
                        .frame(height: 28)
                }
                Section("Grid Region (col / row, zero-indexed)") {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start col").font(.caption).foregroundStyle(.secondary)
                            Stepper("\(colStart)", value: $colStart, in: 0...19)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start row").font(.caption).foregroundStyle(.secondary)
                            Stepper("\(rowStart)", value: $rowStart, in: 0...19)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("End col").font(.caption).foregroundStyle(.secondary)
                            Stepper("\(colEnd)", value: $colEnd, in: 0...19)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("End row").font(.caption).foregroundStyle(.secondary)
                            Stepper("\(rowEnd)", value: $rowEnd, in: 0...19)
                        }
                    }
                    Text("Region: \(selection.encoded)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Name (optional)") {
                    TextField("e.g. Left half", text: $name)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let combo = HotkeyManager.encode(keyCode: keyCode, modifiers: modifiers)
                    onSave(SavedShortcut(keyCombo: combo, selection: selection,
                                        name: name.isEmpty ? nil : name))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 400)
    }
}

// MARK: - Layouts Preferences
struct LayoutsPrefsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newLayoutName   = ""
    @State private var newSnapshotName = ""

    private let relFmt: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: Named Layouts
                VStack(alignment: .leading, spacing: 8) {
                    Text("Named Layouts").font(.headline)
                    Text("Grid-aligned positions. Snaps windows to the nearest grid cell on restore.")
                        .foregroundStyle(.secondary).font(.callout)
                    if appState.layouts.isEmpty {
                        ContentUnavailableView(
                            "No layouts saved yet",
                            systemImage: "rectangle.3.group",
                            description: Text("Arrange your windows, then name and save below.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 80)
                    } else {
                        Table(appState.layouts) {
                            TableColumn("Name", value: \.name)
                            TableColumn("Hotkey") { layout in
                                Text(layout.hotkey ?? "—").foregroundStyle(.secondary)
                            }
                            .width(80)
                            TableColumn("") { layout in
                                Button {
                                    appState.applyLayout(layout)
                                } label: {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                        .help("Restore this layout")
                                }
                                .buttonStyle(.borderless)
                            }
                            .width(28)
                        }
                        .frame(minHeight: 100, maxHeight: 160)
                    }
                    HStack {
                        TextField("New layout name…", text: $newLayoutName)
                            .textFieldStyle(.roundedBorder)
                        Button("Save Current") {
                            guard !newLayoutName.isEmpty else { return }
                            appState.saveCurrentAsLayout(name: newLayoutName)
                            newLayoutName = ""
                        }
                        .disabled(newLayoutName.isEmpty)
                    }
                }

                Divider()

                // MARK: Snapshots
                VStack(alignment: .leading, spacing: 8) {
                    Text("Snapshots").font(.headline)
                    Text("Pixel-exact positions. Restores windows to their exact frame, not grid-aligned.")
                        .foregroundStyle(.secondary).font(.callout)
                    if appState.snapshots.isEmpty {
                        ContentUnavailableView(
                            "No snapshots yet",
                            systemImage: "camera.viewfinder",
                            description: Text("Tap \"Capture Now\" to save the current window arrangement.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 80)
                    } else {
                        Table(appState.snapshots) {
                            TableColumn("Name", value: \.name)
                            TableColumn("Captured") { snap in
                                Text(relFmt.localizedString(for: snap.createdAt, relativeTo: Date()))
                                    .foregroundStyle(.secondary)
                            }
                            .width(80)
                            TableColumn("Win") { snap in
                                Text("\(snap.entries.count)")
                                    .foregroundStyle(.secondary)
                                    .help("\(snap.entries.count) windows captured")
                            }
                            .width(36)
                            TableColumn("") { snap in
                                HStack(spacing: 4) {
                                    Button {
                                        appState.restoreSnapshot(snap)
                                    } label: {
                                        Image(systemName: "arrow.uturn.backward.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Restore this snapshot")
                                    Button {
                                        appState.deleteSnapshot(snap)
                                    } label: {
                                        Image(systemName: "trash").foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Delete this snapshot")
                                }
                            }
                            .width(52)
                        }
                        .frame(minHeight: 100, maxHeight: 200)
                    }
                    HStack {
                        TextField("Snapshot name…", text: $newSnapshotName)
                            .textFieldStyle(.roundedBorder)
                        Button("Capture Now") {
                            guard !newSnapshotName.isEmpty else { return }
                            appState.captureSnapshot(name: newSnapshotName)
                            newSnapshotName = ""
                        }
                        .disabled(newSnapshotName.isEmpty)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Displays Preferences (GH#4)

struct DisplaysPrefsView: View {
    @EnvironmentObject var appState: AppState
    @State private var profileName = ""

    var body: some View {
        Form {
            Section("Current Arrangement") {
                HStack {
                    Label("Profile Key", systemImage: "display.2")
                    Spacer()
                    Text(appState.currentProfileKey.isEmpty ? "—" : appState.currentProfileKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack {
                    TextField("Profile name (e.g. Desk Setup)…", text: $profileName)
                        .textFieldStyle(.roundedBorder)
                    Button("Save as Profile") {
                        guard !profileName.isEmpty else { return }
                        appState.saveCurrentDisplayProfile(name: profileName)
                        profileName = ""
                    }
                    .disabled(profileName.isEmpty || appState.currentProfileKey.isEmpty)
                }
            }

            Section("Saved Profiles") {
                if appState.displayProfiles.isEmpty {
                    Text("No profiles saved yet. Connect your displays and tap \"Save as Profile\".")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(appState.displayProfiles) { profile in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name).fontWeight(.medium)
                                Text(profile.profileKey)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if profile.profileKey == appState.currentProfileKey {
                                Label("Active", systemImage: "checkmark.circle.fill")
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.green)
                                    .help("This profile matches your current display arrangement")
                            }
                            Button {
                                appState.deleteDisplayProfile(profileKey: profile.profileKey)
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .help("Delete profile")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Per-App Rules (GH#6)
struct PerAppRulesPrefsView: View {
    @EnvironmentObject var appState: AppState

    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Per-App Rules").font(.headline)
                Spacer()
                Button { showAddSheet = true } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }

            if appState.perAppRules.isEmpty {
                ContentUnavailableView(
                    "No rules yet",
                    systemImage: "app.badge",
                    description: Text("Tap + to snap an app to a grid region on launch or focus.")
                )
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Table(appState.perAppRules) {
                    TableColumn("App") { rule in
                        Text(appName(for: rule.bundleID))
                    }
                    .width(min: 120)
                    TableColumn("Display") { rule in
                        Text(displayName(for: rule.displayID))
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Trigger") { rule in
                        Text(rule.trigger == .onLaunch ? "On Launch" : "On Focus")
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Region") { rule in
                        Text(rule.selection.encoded)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("") { rule in
                        Button {
                            appState.deletePerAppRule(rule)
                        } label: {
                            Image(systemName: "trash").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .width(28)
                }
                .frame(minHeight: 120)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddPerAppRuleSheet { rule in
                appState.addPerAppRule(rule)
            }
            .environmentObject(appState)
        }
    }

    private func appName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleID
    }

    private func displayName(for displayID: String) -> String {
        appState.displayManager.allDisplayProfiles.first { $0.id == displayID }?.name ?? displayID
    }
}

// MARK: - Add Per-App Rule Sheet
struct AddPerAppRuleSheet: View {
    let onSave: (PerAppRule) -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var runningApps: [(bundleID: String, name: String)] = []
    @State private var selectedBundleID = ""
    @State private var customBundleID   = ""
    @State private var useCustom        = false
    @State private var selectedDisplayIndex = 0
    @State private var trigger: PerAppRule.RuleTrigger = .onLaunch
    @State private var colStart = 0
    @State private var rowStart = 0
    @State private var colEnd   = 2
    @State private var rowEnd   = 2

    private var displays: [(id: String, name: String)] {
        appState.displayManager.allDisplayProfiles
    }

    private var effectiveBundleID: String {
        useCustom ? customBundleID : selectedBundleID
    }

    private var selection: GridSelection {
        GridSelection(
            startCell: GridCell(col: min(colStart, colEnd), row: min(rowStart, rowEnd)),
            endCell:   GridCell(col: max(colStart, colEnd), row: max(rowStart, rowEnd))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Per-App Rule").font(.headline).padding([.top, .horizontal])

            Form {
                Section("App") {
                    Toggle("Enter bundle ID manually", isOn: $useCustom)
                    if useCustom {
                        TextField("com.example.App", text: $customBundleID)
                    } else {
                        Picker("Running App", selection: $selectedBundleID) {
                            ForEach(runningApps, id: \.bundleID) { app in
                                Text(app.name).tag(app.bundleID)
                            }
                        }
                    }
                }

                Section("Trigger") {
                    Picker("When", selection: $trigger) {
                        Text("On Launch").tag(PerAppRule.RuleTrigger.onLaunch)
                        Text("On Focus").tag(PerAppRule.RuleTrigger.onFocus)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Display") {
                    if displays.isEmpty {
                        Text("No displays detected").foregroundStyle(.secondary)
                    } else {
                        Picker("Display", selection: $selectedDisplayIndex) {
                            ForEach(displays.indices, id: \.self) { i in
                                Text(displays[i].name).tag(i)
                            }
                        }
                    }
                }

                Section("Grid Region (col / row, zero-indexed)") {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start col").font(.caption).foregroundStyle(.secondary)
                            Stepper("\(colStart)", value: $colStart, in: 0...19)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start row").font(.caption).foregroundStyle(.secondary)
                            Stepper("\(rowStart)", value: $rowStart, in: 0...19)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("End col").font(.caption).foregroundStyle(.secondary)
                            Stepper("\(colEnd)", value: $colEnd, in: 0...19)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("End row").font(.caption).foregroundStyle(.secondary)
                            Stepper("\(rowEnd)", value: $rowEnd, in: 0...19)
                        }
                    }
                    Text("Region: \(selection.encoded)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let displayID = selectedDisplayIndex < displays.count
                        ? displays[selectedDisplayIndex].id : "display_main"
                    onSave(PerAppRule(bundleID: effectiveBundleID, displayID: displayID,
                                     selection: selection, trigger: trigger))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(effectiveBundleID.isEmpty)
            }
            .padding()
        }
        .frame(width: 440, height: 460)
        .onAppear { loadRunningApps() }
    }

    private func loadRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (bundleID: String, name: String)? in
                guard let bid = app.bundleIdentifier, !bid.isEmpty else { return nil }
                return (bundleID: bid, name: app.localizedName ?? bid)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var seen = Set<String>()
        runningApps = apps.filter { seen.insert($0.bundleID).inserted }
        if let first = runningApps.first { selectedBundleID = first.bundleID }
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
            Section("Global Hotkey") {
                HStack {
                    Text("Invoke grid overlay")
                    Spacer()
                    KeyRecorderView(
                        keyCode: Binding(
                            get: { appState.hotkeyCode },
                            set: { appState.updateHotkey(keyCode: $0,
                                                         modifiers: appState.hotkeyModifiers) }
                        ),
                        modifiers: Binding(
                            get: { appState.hotkeyModifiers },
                            set: { appState.updateHotkey(keyCode: appState.hotkeyCode,
                                                         modifiers: $0) }
                        )
                    )
                    .frame(width: 120, height: 28)
                }
                Button("Reset to ⌘⇧G") { appState.resetHotkey() }
                    .controlSize(.small)
            }
            Section("Companion API") {
                Text("Local API server on port 14731\nEvery UI action is reachable via Claude, other AI, SDK, or API.")
                    .foregroundStyle(.secondary)
            }
            Section("About") {
                HStack {
                    Text("GridForge")
                    Spacer()
                    Text("v\(AppVersion.current)").foregroundStyle(.secondary)
                }
                Link("View on GitHub",
                     destination: URL(string: "https://github.com/lswingrover/gridforge")!)
            }
        }
        .formStyle(.grouped)
    }
}
