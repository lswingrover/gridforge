import CoreGraphics
import Foundation

// MARK: - GridCell

/// A single cell address within a grid (zero-indexed, top-left origin)
public struct GridCell: Hashable, Equatable, Sendable, Codable {
    public let col: Int
    public let row: Int

    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }
}

// MARK: - GridSelection

/// A rectangular selection spanning one or more grid cells.
/// startCell and endCell may be in any order — use normalized accessors.
public struct GridSelection: Equatable, Sendable, Codable {
    public let startCell: GridCell
    public let endCell: GridCell

    public init(startCell: GridCell, endCell: GridCell) {
        self.startCell = startCell
        self.endCell = endCell
    }

    public var normalizedStartCol: Int { min(startCell.col, endCell.col) }
    public var normalizedStartRow: Int { min(startCell.row, endCell.row) }
    public var normalizedEndCol:   Int { max(startCell.col, endCell.col) }
    public var normalizedEndRow:   Int { max(startCell.row, endCell.row) }

    public var spanCols: Int { normalizedEndCol - normalizedStartCol + 1 }
    public var spanRows: Int { normalizedEndRow - normalizedStartRow + 1 }

    /// Compact storage string, e.g. "0,0-5,3"
    public var encoded: String {
        "\(normalizedStartCol),\(normalizedStartRow)-\(normalizedEndCol),\(normalizedEndRow)"
    }

    public static func decode(_ string: String) -> GridSelection? {
        let parts = string.split(separator: "-")
        guard parts.count == 2 else { return nil }
        let start = parts[0].split(separator: ",")
        let end   = parts[1].split(separator: ",")
        guard start.count == 2, end.count == 2,
              let sc = Int(start[0]), let sr = Int(start[1]),
              let ec = Int(end[0]),   let er = Int(end[1]) else { return nil }
        return GridSelection(startCell: GridCell(col: sc, row: sr),
                             endCell:   GridCell(col: ec, row: er))
    }
}

// MARK: - GridCalculator

/// Pure geometry: converts grid selections ↔ CGRects within a given screen frame.
/// Coordinate convention: top-left origin (Y increases downward), matching isFlipped NSView.
public struct GridCalculator: Sendable {
    public let columns:    Int
    public let rows:       Int
    public let gapPixels:  CGFloat

    public init(columns: Int, rows: Int, gapPixels: CGFloat = 0) {
        self.columns   = max(1, columns)
        self.rows      = max(1, rows)
        self.gapPixels = max(0, gapPixels)
    }

    /// Cell dimensions (without gap)
    public var cellWidth:  CGFloat = 0
    public var cellHeight: CGFloat = 0

    /// Returns the CGRect (in the coordinate space of screenFrame) for a given selection.
    public func frame(for selection: GridSelection, in screenFrame: CGRect) -> CGRect {
        let totalGapX  = gapPixels * CGFloat(columns - 1)
        let totalGapY  = gapPixels * CGFloat(rows    - 1)
        let cellW      = (screenFrame.width  - totalGapX) / CGFloat(columns)
        let cellH      = (screenFrame.height - totalGapY) / CGFloat(rows)

        let sc = selection.normalizedStartCol
        let sr = selection.normalizedStartRow

        let x = screenFrame.minX + CGFloat(sc) * (cellW + gapPixels)
        let y = screenFrame.minY + CGFloat(sr) * (cellH + gapPixels)
        let w = CGFloat(selection.spanCols) * cellW + CGFloat(selection.spanCols - 1) * gapPixels
        let h = CGFloat(selection.spanRows) * cellH + CGFloat(selection.spanRows - 1) * gapPixels

        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Returns the grid cell that contains a given point (relative to screenFrame origin).
    /// Returns nil if the point is outside screenFrame.
    public func cell(at point: CGPoint, in screenFrame: CGRect) -> GridCell? {
        guard screenFrame.contains(point) else { return nil }

        let totalGapX = gapPixels * CGFloat(columns - 1)
        let totalGapY = gapPixels * CGFloat(rows    - 1)
        let cellW     = (screenFrame.width  - totalGapX) / CGFloat(columns)
        let cellH     = (screenFrame.height - totalGapY) / CGFloat(rows)

        let localX = point.x - screenFrame.minX
        let localY = point.y - screenFrame.minY

        let col = min(Int(localX / (cellW + gapPixels)), columns - 1)
        let row = min(Int(localY / (cellH + gapPixels)), rows    - 1)

        return GridCell(col: max(0, col), row: max(0, row))
    }

    /// Converts an absolute CGRect (screen coordinates) back to the closest GridSelection.
    public func selection(for rect: CGRect, in screenFrame: CGRect) -> GridSelection {
        let topLeft     = CGPoint(x: rect.minX + 1, y: rect.minY + 1)
        let bottomRight = CGPoint(x: rect.maxX - 1, y: rect.maxY - 1)
        let start = cell(at: topLeft,     in: screenFrame) ?? GridCell(col: 0, row: 0)
        let end   = cell(at: bottomRight, in: screenFrame) ?? GridCell(col: columns - 1, row: rows - 1)
        return GridSelection(startCell: start, endCell: end)
    }
}
