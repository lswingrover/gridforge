import AppKit
import GridForgeCore

@MainActor
final class DisplayManager {

    static let shared = DisplayManager()
    private init() {}

    /// Stable string identifier for a given NSScreen.
    func displayID(for screen: NSScreen) -> String {
        if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return "display_\(num)"
        }
        return "display_main"
    }

    /// The NSScreen matching a stored displayID, or nil.
    func screen(for displayID: String) -> NSScreen? {
        NSScreen.screens.first { [self] s in self.displayID(for: s) == displayID }
    }

    /// A human-readable name for a display (e.g. "Built-in Retina Display").
    func displayName(for screen: NSScreen) -> String {
        screen.localizedName
    }

    /// All current display profiles as (id, name) pairs.
    var allDisplayProfiles: [(id: String, name: String)] {
        NSScreen.screens.map { (id: displayID(for: $0), name: displayName(for: $0)) }
    }

    /// A canonical string describing the current display arrangement (for profile switching).
    var currentProfileKey: String {
        NSScreen.screens
            .compactMap { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID }
            .sorted()
            .map { "\($0)" }
            .joined(separator: "+")
    }
}
