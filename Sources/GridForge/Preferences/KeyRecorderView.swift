/// KeyRecorderView.swift — SwiftUI wrapper around a key-recording NSView.
///
/// The user clicks the view to enter recording mode, then presses a key combo
/// (must include at least one of ⌘ ⌥ ⌃ ⇧). ESC cancels without updating
/// bindings. On a valid combo: bindings update and onRecorded fires.
import AppKit
import SwiftUI

// MARK: - SwiftUI wrapper

struct KeyRecorderView: NSViewRepresentable {

    @Binding var keyCode:   UInt16
    @Binding var modifiers: NSEvent.ModifierFlags

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let v        = KeyRecorderNSView()
        v.keyCode    = keyCode
        v.modifiers  = modifiers
        v.onRecorded = { code, mods in
            keyCode   = code
            modifiers = mods
        }
        return v
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        // Only push external changes when not actively recording
        guard !nsView.isRecording else { return }
        nsView.keyCode    = keyCode
        nsView.modifiers  = modifiers
        nsView.needsDisplay = true
    }
}

// MARK: - KeyRecorderNSView

final class KeyRecorderNSView: NSView {

    var keyCode:    UInt16                = 5                   // G
    var modifiers:  NSEvent.ModifierFlags = [.command, .shift]
    var onRecorded: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    private(set) var isRecording = false

    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 24) }
    override var acceptsFirstResponder: Bool  { true }

    // MARK: Interaction

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording  = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        // ESC — cancel without change
        if event.keyCode == 53 {
            isRecording = false
            window?.makeFirstResponder(nil)
            needsDisplay = true
            return
        }

        let mods = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function, .help])

        // Require at least one real modifier
        guard mods.contains(.command) || mods.contains(.option)
                || mods.contains(.control) || mods.contains(.shift) else { return }

        keyCode   = event.keyCode
        modifiers = mods
        isRecording = false
        window?.makeFirstResponder(nil)
        onRecorded?(keyCode, modifiers)
        needsDisplay = true
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Background
        let bg: NSColor = isRecording
            ? NSColor.selectedControlColor.withAlphaComponent(0.25)
            : NSColor.controlBackgroundColor
        bg.setFill()
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: 5, yRadius: 5
        )
        path.fill()

        let borderAlpha: CGFloat = isRecording ? 0.8 : 0.4
        NSColor.separatorColor.withAlphaComponent(borderAlpha).setStroke()
        path.lineWidth = 1
        path.stroke()

        // Label
        let label: String = isRecording
            ? "Type shortcut…"
            : HotkeyManager.displayString(keyCode: keyCode, modifiers: modifiers)

        let attrs: [NSAttributedString.Key: Any] = [
            .font:            NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: isRecording ? NSColor.placeholderTextColor : NSColor.labelColor
        ]
        let astr    = NSAttributedString(string: label, attributes: attrs)
        let sz      = astr.size()
        let origin  = NSPoint(
            x: (bounds.width  - sz.width)  / 2,
            y: (bounds.height - sz.height) / 2
        )
        astr.draw(at: origin)
    }
}
