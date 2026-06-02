import AppKit
import GridForgeCore

/// Creates and manages the full-screen NSPanel grid overlay.
/// One instance per app; panel is recreated on each activation.
@MainActor
final class GridOverlayController {

    private var panel:      NSPanel?
    private var canvasView: GridCanvasView?
    private let db = DatabaseManager.shared

    // MARK: - Show

    func show(on screen: NSScreen, completion: @escaping (GridSelection?) -> Void) {
        dismiss()       // defensive: close any existing overlay

        let displayID = displayIDFor(screen)
        let config    = db.loadGridConfig(displayID: displayID)

        // Full-screen borderless panel, above everything
        let p = NSPanel(
            contentRect: screen.frame,
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        p.level                = .screenSaver
        p.backgroundColor      = .clear
        p.isOpaque             = false
        p.hasShadow            = false
        p.ignoresMouseEvents   = false
        p.collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.hidesOnDeactivate    = false
        p.isReleasedWhenClosed = false
        p.acceptsMouseMovedEvents = true

        // Canvas
        let canvas = GridCanvasView(frame: NSRect(origin: .zero, size: screen.frame.size))
        canvas.columns   = config.columns
        canvas.rows      = config.rows
        canvas.gapPixels = config.gapPixels

        canvas.onSelection = { [weak self] selection in
            self?.dismiss()
            completion(selection)
        }
        canvas.onDismiss = { [weak self] in
            self?.dismiss()
            completion(nil)
        }

        p.contentView = canvas
        self.panel      = p
        self.canvasView = canvas

        p.makeKeyAndOrderFront(nil)
        canvas.window?.makeFirstResponder(canvas)

        // Also install a global ESC monitor as belt-and-suspenders
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor [weak self] in
                    self?.dismiss()
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        panel?.orderOut(nil)
        panel      = nil
        canvasView = nil
    }

    // MARK: - Helpers

    private func displayIDFor(_ screen: NSScreen) -> String {
        if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return "display_\(num)"
        }
        return "display_main"
    }
}
