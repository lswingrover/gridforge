import AppKit
/// Registers a global keyboard shortcut using NSEvent global monitoring.
/// Default: ⌘⇧G  (configurable — keyCode + modifiers stored in UserDefaults).
final class HotkeyManager {
    var onActivate: (() -> Void)?
    private var monitor: Any?

    // Internal so AppState can reference defaults for reset + initial sync
    static let defaultKeyCode:   UInt16               = 5        // G
    static let defaultModifiers: NSEvent.ModifierFlags = [.command, .shift]

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
        UserDefaults.standard.set(Int(keyCode),       forKey: "gf_hotkey_code")
        UserDefaults.standard.set(modifiers.rawValue, forKey: "gf_hotkey_mods")
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

    // MARK: - Static display / encode helpers (used by KeyRecorderView + PreferencesView)

    /// Maps Carbon key codes to readable glyphs for display.
    private static let keyMap: [UInt16: String] = [
        // Letters (QWERTY layout, Carbon key codes)
        0: "A",  1: "S",  2: "D",  3: "F",  4: "H",  5: "G",  6: "Z",  7: "X",
        8: "C",  9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y",
        17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K",
        45: "N", 46: "M",
        // Number row
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 33: "[", 39: "'", 41: ";", 42: "\\", 43: ",", 44: "/", 47: ".",
        // Function keys
        122: "F1", 120: "F2", 99: "F3", 118: "F4",  96: "F5",
         97: "F6", 131: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12",
        // Special
        48: "⇥", 51: "⌫", 36: "↩", 49: "Space", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    /// Returns a human-readable display string, e.g. "⌘⇧G".
    static func displayString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option)  { parts.append("⌥") }
        if modifiers.contains(.shift)   { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyMap[keyCode] ?? "Key(\(keyCode))")
        return parts.joined()
    }

    /// Convenience: decodes a stored combo string then formats for display.
    static func displayString(forCombo combo: String) -> String {
        guard let (code, mods) = decode(combo) else { return combo }
        return displayString(keyCode: code, modifiers: mods)
    }

    /// Encodes keyCode + modifierFlags as a stable storage string "code:raw".
    static func encode(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        "\(keyCode):\(modifiers.rawValue)"
    }

    /// Decodes a storage string produced by encode(_:_:).
    static func decode(_ combo: String) -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags)? {
        let parts = combo.split(separator: ":")
        guard parts.count == 2,
              let code = UInt16(parts[0]),
              let raw  = UInt(parts[1]) else { return nil }
        return (code, NSEvent.ModifierFlags(rawValue: raw))
    }
}
