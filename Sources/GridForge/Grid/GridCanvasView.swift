import AppKit
import GridForgeCore

/// Full-screen NSView that draws the grid overlay and tracks mouse drag.
/// Uses isFlipped = true so row 0 is at the top — consistent with GridCalculator.
final class GridCanvasView: NSView {

    // Config
    var columns:    Int     = 6
    var rows:       Int     = 4
    var gapPixels:  CGFloat = 0

    // Callbacks
    var onSelection: ((GridSelection) -> Void)?
    var onDismiss:   (() -> Void)?

    // Drag state
    private var dragStartCell:   GridCell?
    private var dragCurrentCell: GridCell?

    // Key monitor for ESC
    private var keyMonitor: Any?

    // MARK: - Setup

    override var isFlipped: Bool { true }   // top-left origin
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { self?.onDismiss?(); return nil }
                return event
            }
        } else {
            if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Semi-transparent backdrop
        NSColor.black.withAlphaComponent(0.38).setFill()
        bounds.fill()

        drawGridLines()

        if let start = dragStartCell, let end = dragCurrentCell {
            drawSelection(GridSelection(startCell: start, endCell: end))
        }
    }

    private func drawGridLines() {
        let cellW = bounds.width  / CGFloat(columns)
        let cellH = bounds.height / CGFloat(rows)

        NSColor.white.withAlphaComponent(0.28).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 0.5

        for col in 1..<columns {
            let x = CGFloat(col) * cellW
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: bounds.height))
        }
        for row in 1..<rows {
            let y = CGFloat(row) * cellH
            path.move(to: NSPoint(x: 0, y: y))
            path.line(to: NSPoint(x: bounds.width, y: y))
        }
        path.stroke()

        // Outer border
        NSColor.white.withAlphaComponent(0.12).setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        border.lineWidth = 1
        border.stroke()
    }

    private func drawSelection(_ selection: GridSelection) {
        let calc  = GridCalculator(columns: columns, rows: rows, gapPixels: gapPixels)
        let frame = calc.frame(for: selection, in: CGRect(origin: .zero, size: bounds.size))

        // Fill
        NSColor.controlAccentColor.withAlphaComponent(0.42).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 3, yRadius: 3).fill()

        // Border
        NSColor.controlAccentColor.setStroke()
        let border = NSBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3)
        border.lineWidth = 2
        border.stroke()

        // Size label (e.g. "3×2")
        let label = "\(selection.spanCols)×\(selection.spanRows)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font:            NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        let str  = NSAttributedString(string: label, attributes: attrs)
        let size = str.size()
        let pt   = NSPoint(x: frame.midX - size.width / 2,
                           y: frame.midY - size.height / 2)
        str.draw(at: pt)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        dragStartCell   = cellAt(pt)
        dragCurrentCell = dragStartCell
        needsDisplay    = true
    }

    override func mouseDragged(with event: NSEvent) {
        let pt        = convert(event.locationInWindow, from: nil)
        dragCurrentCell = cellAt(pt)
        needsDisplay    = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStartCell   = nil
            dragCurrentCell = nil
            needsDisplay    = true
        }
        guard let start = dragStartCell, let end = dragCurrentCell else { return }
        onSelection?(GridSelection(startCell: start, endCell: end))
    }

    override func rightMouseDown(with event: NSEvent)  { onDismiss?() }
    override func otherMouseDown(with event: NSEvent)  { onDismiss?() }

    // MARK: - Helpers

    private func cellAt(_ point: NSPoint) -> GridCell? {
        let calc = GridCalculator(columns: columns, rows: rows, gapPixels: gapPixels)
        return calc.cell(at: CGPoint(x: point.x, y: point.y),
                         in: CGRect(origin: .zero, size: bounds.size))
    }
}
