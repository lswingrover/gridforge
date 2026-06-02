import AppKit

/// Registers a global keyboard shortcut using NSEvent global monitoring.
/// Default: ⌘⇧G  (configurable — keyCode + modifiers stored in UserDefaults).
final class HotkeyManager {

    var onActivate: (() -> Void)?

    private var monitor: Any?

    // Persisted defaults
    private static let defaultKeyCode:   UInt16              = 5        // G
    private static let defaultModifiers: NSEvent.ModifierFlags = [.command, .shift]

    var keyCode:   UInt16               = HotkeyManager.defaultKeyCode
    var modifiers: NSEvent.ModifierFlags = HotkeyManager.defaultModifiers

    init() {
        load()
    }

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == self.keyCode && flags == self.modifiers {
                self.onActivate?()
            }
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }

    func update(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode   = keyCode
        self.modifiers = modifiers
        save()
        start()     // restart with new combo
    }

    func resetToDefault() {
        update(keyCode:   HotkeyManager.defaultKeyCode,
               modifiers: HotkeyManager.defaultModifiers)
    }

    // MARK: - Persistence (UserDefaults — no secrets)

    private func save() {
        UserDefaults.standard.set(Int(keyCode),                      forKey: "gf_hotkey_code")
        UserDefaults.standard.set(modifiers.rawValue,                forKey: "gf_hotkey_mods")
    }

    private func load() {
        if let code = UserDefaults.standard.object(forKey: "gf_hotkey_code") as? Int {
            keyCode = UInt16(code)
        }
        if let raw = UserDefaults.standard.object(forKey: "gf_hotkey_mods") as? UInt {
            modifiers = NSEvent.ModifierFlags(rawValue: raw)
        }
    }

    deinit { stop() }
}
