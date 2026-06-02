import AppKit
import ApplicationServices
import GridForgeCore

// MARK: - WindowManager

@MainActor
final class WindowManager {
    static let shared = WindowManager()
    private init() {}

    // MARK: - Accessibility

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary)
    }

    func requestAccessibilityPermission() {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary)
    }

    // MARK: - Focused Window

    /// The frame (bottom-left origin, global screen coords) of the currently focused window.
    func focusedWindowFrame() throws -> CGRect {
        let win = try focusedWindow()
        return try frameOf(win)
    }

    /// Move + resize the focused window to the given CGRect (bottom-left origin, global coords).
    func setFocusedWindowFrame(_ frame: CGRect) throws {
        let win = try focusedWindow()
        try setFrame(frame, on: win)
    }

    /// Move + resize any window belonging to the given running application.
    /// Targets the first (main) window.
    func setWindowFrame(_ frame: CGRect, forApp app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString,
                                            &windowsRef) == .success,
              let windowList = windowsRef as? [AXUIElement],
              let firstWindow = windowList.first else { return }
        try? setFrame(frame, on: firstWindow)
    }

    // MARK: - Screen

    /// The NSScreen that currently contains the focused window, or main screen as fallback.
    func screenForFocusedWindow() -> NSScreen {
        guard let frame = try? focusedWindowFrame() else {
            return NSScreen.main ?? NSScreen.screens[0]
        }
        return NSScreen.screens.first(where: { $0.frame.intersects(frame) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    // MARK: - All Visible Windows (layout + snapshot capture)

    /// Returns every AX-visible, non-minimized window across all running applications.
    /// Each entry: (bundleID, displayID, frame in global screen coords / bottom-left origin).
    /// Minimized, hidden, non-window AX roles, or zero-size frames are silently skipped.
    func allVisibleWindows() -> [(bundleID: String, displayID: String, frame: CGRect)] {
        var results: [(bundleID: String, displayID: String, frame: CGRect)] = []

        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != nil
        }

        for app in apps {
            guard let bundleID = app.bundleIdentifier else { continue }
            let axApp = AXUIElementCreateApplication(app.processIdentifier)

            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                      axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windowList = windowsRef as? [AXUIElement] else { continue }

            for win in windowList {
                // Skip minimized windows
                var minRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(
                       win, kAXMinimizedAttribute as CFString, &minRef) == .success,
                   let minimized = minRef as? Bool, minimized { continue }

                // Skip non-window AX roles (drawers, sheets, etc.)
                var roleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(
                       win, kAXRoleAttribute as CFString, &roleRef) == .success,
                   let role = roleRef as? String,
                   role != (kAXWindowRole as String) { continue }

                guard let frame = try? frameOf(win),
                      frame.width > 1, frame.height > 1 else { continue }

                // Find which display this window's centre sits on
                let centre = CGPoint(x: frame.midX, y: frame.midY)
                let screen = NSScreen.screens.first(where: { $0.frame.contains(centre) })
                             ?? NSScreen.screens.first(where: { $0.frame.intersects(frame) })
                             ?? NSScreen.main ?? NSScreen.screens[0]

                let displayID = DisplayManager.shared.displayID(for: screen)
                results.append((bundleID: bundleID, displayID: displayID, frame: frame))
            }
        }
        return results
    }

    // MARK: - Private helpers

    private func focusedWindow() throws -> AXUIElement {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw WindowManagerError.noFrontmostApp
        }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            axApp, kAXFocusedWindowAttribute as CFString, &ref)
        guard err == .success, let win = ref else {
            throw WindowManagerError.noFocusedWindow(err)
        }
        // swiftlint:disable:next force_cast
        return (win as! AXUIElement)
    }

    private func frameOf(_ win: AXUIElement) throws -> CGRect {
        var posRef:  CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString,
                                            &posRef) == .success,
              AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString,
                                            &sizeRef) == .success,
              let pv = posRef, let sv = sizeRef else {
            throw WindowManagerError.attributeReadFailed
        }
        var position = CGPoint.zero
        var size     = CGSize.zero
        // swiftlint:disable:next force_cast
        AXValueGetValue(pv as! AXValue, .cgPoint, &position)
        // swiftlint:disable:next force_cast
        AXValueGetValue(sv as! AXValue, .cgSize,  &size)
        return CGRect(origin: position, size: size)
    }

    private func setFrame(_ frame: CGRect, on win: AXUIElement) throws {
        var pos  = frame.origin
        var size = frame.size
        guard let posVal  = AXValueCreate(.cgPoint, &pos),
              let sizeVal = AXValueCreate(.cgSize,  &size) else {
            throw WindowManagerError.valueCreateFailed
        }
        let posErr  = AXUIElementSetAttributeValue(
            win, kAXPositionAttribute as CFString, posVal)
        let sizeErr = AXUIElementSetAttributeValue(
            win, kAXSizeAttribute as CFString, sizeVal)
        if posErr != .success {
            throw WindowManagerError.setFailed(kAXPositionAttribute, posErr)
        }
        if sizeErr != .success {
            throw WindowManagerError.setFailed(kAXSizeAttribute, sizeErr)
        }
    }
}

// MARK: - Errors

enum WindowManagerError: Error, CustomStringConvertible {
    case noFrontmostApp
    case noFocusedWindow(AXError)
    case attributeReadFailed
    case valueCreateFailed
    case setFailed(String, AXError)

    var description: String {
        switch self {
        case .noFrontmostApp:
            return "No frontmost application"
        case .noFocusedWindow(let e):
            return "No focused window (AXError \(e.rawValue))"
        case .attributeReadFailed:
            return "Failed to read AX position/size"
        case .valueCreateFailed:
            return "AXValueCreate returned nil"
        case .setFailed(let attr, let e):
            return "Failed to set \(attr) (AXError \(e.rawValue))"
        }
    }
}
