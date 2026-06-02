import AppKit
import Combine
import GridForgeCore

/// Central shared state. Owns hotkey manager, overlay controller, window manager.
/// All mutations on the main thread.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // Published state
    @Published var isOverlayVisible  = false
    @Published var layouts:      [NamedLayout]  = []
    @Published var perAppRules:  [PerAppRule]   = []
    @Published var shortcuts:    [SavedShortcut] = []
    @Published var accessibilityGranted          = false

    // Hotkey -- mirrored from HotkeyManager so views can observe changes
    @Published var hotkeyCode:      UInt16               = HotkeyManager.defaultKeyCode
    @Published var hotkeyModifiers: NSEvent.ModifierFlags = HotkeyManager.defaultModifiers

    // Sub-systems
    let windowManager     = WindowManager.shared
    let displayManager    = DisplayManager.shared
    let overlayController = GridOverlayController()
    // Exposed (non-private) so PreferencesView can drive KeyRecorderView bindings
    let hotkeyManager     = HotkeyManager()
    private let db        = DatabaseManager.shared

    private init() {
        setup()
    }

    private func setup() {
        // Open DB
        do {
            try db.open()
        } catch {
            NSLog("GridForge: DB open failed: \(error)")
        }

        // Check AX permission
        accessibilityGranted = windowManager.hasAccessibilityPermission

        // Load persisted data
        layouts     = db.loadLayouts()
        perAppRules = db.loadPerAppRules()
        shortcuts   = db.loadShortcuts()

        // Sync published hotkey state from persisted HotkeyManager values
        hotkeyCode      = hotkeyManager.keyCode
        hotkeyModifiers = hotkeyManager.modifiers

        // Wire hotkey
        hotkeyManager.onActivate = { [weak self] in
            Task { @MainActor [weak self] in
                self?.activateGrid()
            }
        }
        hotkeyManager.start()

        // Observe app launches for per-app rules
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            Task { @MainActor [weak self] in
                self?.applyPerAppRule(bundleID: bundleID, trigger: .onLaunch)
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            Task { @MainActor [weak self] in
                self?.applyPerAppRule(bundleID: bundleID, trigger: .onFocus)
            }
        }
    }

    // MARK: - Grid Activation

    func activateGrid() {
        guard !isOverlayVisible else { return }
        guard accessibilityGranted else {
            windowManager.requestAccessibilityPermission()
            return
        }
        let screen = windowManager.screenForFocusedWindow()
        isOverlayVisible = true
        overlayController.show(on: screen) { [weak self] selection in
            Task { @MainActor [weak self] in
                self?.isOverlayVisible = false
                guard let self, let selection else { return }
                self.applySelection(selection, on: screen)
            }
        }
    }

    // MARK: - Window Placement

    func applySelection(_ selection: GridSelection, on screen: NSScreen) {
        let displayID  = displayManager.displayID(for: screen)
        let config     = db.loadGridConfig(displayID: displayID)
        let calculator = GridCalculator(columns: config.columns, rows: config.rows, gapPixels: config.gapPixels)
        _ = screen.frame
        let visibleFrame = screen.visibleFrame
        let calcFrame = CGRect(x: visibleFrame.minX,
                               y: 0,
                               width:  visibleFrame.width,
                               height: visibleFrame.height)
        var targetFrame = calculator.frame(for: selection, in: calcFrame)
        let flippedY = visibleFrame.maxY - targetFrame.maxY
        targetFrame = CGRect(x: visibleFrame.minX + targetFrame.minX,
                             y: flippedY,
                             width:  targetFrame.width,
                             height: targetFrame.height)
        do {
            try windowManager.setFocusedWindowFrame(targetFrame)
            let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            db.logAction(action: "snap", displayID: displayID, selection: selection,
                         appBundle: frontBundle)
        } catch {
            NSLog("GridForge: setFocusedWindowFrame failed: \(error)")
        }
    }

    // MARK: - Layouts

    func saveCurrentAsLayout(name: String) {
        let windows = windowManager.allVisibleWindows()
        var entries: [LayoutEntry] = []

        for win in windows {
            let config = db.loadGridConfig(displayID: win.displayID)
            guard let screen = displayManager.screen(for: win.displayID) else { continue }

            // GridCalculator uses top-left origin; convert from macOS bottom-left coords
            let visFrame  = screen.visibleFrame
            let calcFrame = CGRect(x: 0, y: 0, width: visFrame.width, height: visFrame.height)

            // Translate window frame to display-local, top-left-origin coordinates
            let localX    = win.frame.minX - visFrame.minX
            let flippedY  = visFrame.maxY - win.frame.maxY
            let localFrame = CGRect(x: localX, y: flippedY,
                                    width: win.frame.width, height: win.frame.height)

            let calc      = GridCalculator(columns: config.columns, rows: config.rows,
                                           gapPixels: config.gapPixels)
            let selection = calc.selection(for: localFrame, in: calcFrame)
            entries.append(LayoutEntry(bundleID: win.bundleID, displayID: win.displayID,
                                       selection: selection))
        }

        let layout = NamedLayout(name: name, entries: entries)
        try? db.saveLayout(layout)
        layouts   = db.loadLayouts()
        db.logAction(action: "save_layout", layoutName: name)
        NSLog("GridForge: saved layout '%@' with %d entries", name, entries.count)
    }

    func applyLayout(_ layout: NamedLayout) {
        for entry in layout.entries {
            guard let screen = displayManager.screen(for: entry.displayID),
                  let app = NSRunningApplication.runningApplications(
                      withBundleIdentifier: entry.bundleID).first else { continue }
            let config     = db.loadGridConfig(displayID: entry.displayID)
            let calculator = GridCalculator(columns: config.columns, rows: config.rows, gapPixels: config.gapPixels)
            let visFrame   = screen.visibleFrame
            let calcFrame  = CGRect(x: 0, y: 0, width: visFrame.width, height: visFrame.height)
            var targetFrame = calculator.frame(for: entry.selection, in: calcFrame)
            let flippedY    = visFrame.maxY - targetFrame.maxY
            targetFrame     = CGRect(x: visFrame.minX + targetFrame.minX,
                                     y: flippedY,
                                     width:  targetFrame.width,
                                     height: targetFrame.height)
            windowManager.setWindowFrame(targetFrame, forApp: app)
        }
        db.logAction(action: "apply_layout", layoutName: layout.name)
    }

    // MARK: - Shortcuts

    func addShortcut(_ shortcut: SavedShortcut) {
        try? db.saveShortcut(shortcut)
        shortcuts = db.loadShortcuts()
    }

    func deleteShortcut(_ shortcut: SavedShortcut) {
        db.deleteShortcut(id: shortcut.id)
        shortcuts = db.loadShortcuts()
    }

    // MARK: - Hotkey

    func updateHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        hotkeyManager.update(keyCode: keyCode, modifiers: modifiers)
        hotkeyCode      = keyCode
        hotkeyModifiers = modifiers
    }

    func resetHotkey() {
        updateHotkey(keyCode:   HotkeyManager.defaultKeyCode,
                     modifiers: HotkeyManager.defaultModifiers)
    }

    // MARK: - Per-App Rules

    private func applyPerAppRule(bundleID: String, trigger: PerAppRule.RuleTrigger) {
        guard let rule = perAppRules.first(where: { $0.bundleID == bundleID && $0.trigger == trigger }),
              let screen = displayManager.screen(for: rule.displayID),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        else { return }
        let config     = db.loadGridConfig(displayID: rule.displayID)
        let calculator = GridCalculator(columns: config.columns, rows: config.rows, gapPixels: config.gapPixels)
        let visFrame   = screen.visibleFrame
        let calcFrame  = CGRect(x: 0, y: 0, width: visFrame.width, height: visFrame.height)
        var targetFrame = calculator.frame(for: rule.selection, in: calcFrame)
        let flippedY    = visFrame.maxY - targetFrame.maxY
        targetFrame     = CGRect(x: visFrame.minX + targetFrame.minX,
                                 y: flippedY,
                                 width:  targetFrame.width,
                                 height: targetFrame.height)
        windowManager.setWindowFrame(targetFrame, forApp: app)
        db.logAction(action: "per_app_rule", displayID: rule.displayID,
                     selection: rule.selection, appBundle: bundleID)
    }
}
