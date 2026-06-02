import XCTest
@testable import GridForgeCore

final class GridPositionTests: XCTestCase {

    // MARK: - GridCell

    func testGridCellEquality() {
        XCTAssertEqual(GridCell(col: 2, row: 3), GridCell(col: 2, row: 3))
        XCTAssertNotEqual(GridCell(col: 2, row: 3), GridCell(col: 3, row: 2))
    }

    func testGridCellHashable() {
        let set: Set<GridCell> = [GridCell(col: 0, row: 0), GridCell(col: 0, row: 0), GridCell(col: 1, row: 1)]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - GridSelection normalisation

    func testSelectionNormalisesForwardDrag() {
        let sel = GridSelection(startCell: GridCell(col: 2, row: 1),
                                endCell:   GridCell(col: 4, row: 3))
        XCTAssertEqual(sel.normalizedStartCol, 2)
        XCTAssertEqual(sel.normalizedStartRow, 1)
        XCTAssertEqual(sel.normalizedEndCol,   4)
        XCTAssertEqual(sel.normalizedEndRow,   3)
        XCTAssertEqual(sel.spanCols, 3)
        XCTAssertEqual(sel.spanRows, 3)
    }

    func testSelectionNormalisesReverseDrag() {
        let sel = GridSelection(startCell: GridCell(col: 4, row: 3),
                                endCell:   GridCell(col: 2, row: 1))
        XCTAssertEqual(sel.normalizedStartCol, 2)
        XCTAssertEqual(sel.normalizedStartRow, 1)
        XCTAssertEqual(sel.normalizedEndCol,   4)
        XCTAssertEqual(sel.normalizedEndRow,   3)
    }

    func testSingleCellSelection() {
        let sel = GridSelection(startCell: GridCell(col: 3, row: 3),
                                endCell:   GridCell(col: 3, row: 3))
        XCTAssertEqual(sel.spanCols, 1)
        XCTAssertEqual(sel.spanRows, 1)
    }

    // MARK: - GridSelection encoding

    func testSelectionEncoding() {
        let sel = GridSelection(startCell: GridCell(col: 0, row: 0),
                                endCell:   GridCell(col: 5, row: 3))
        XCTAssertEqual(sel.encoded, "0,0-5,3")
    }

    func testSelectionRoundTrip() {
        let original = GridSelection(startCell: GridCell(col: 1, row: 2),
                                     endCell:   GridCell(col: 4, row: 3))
        let decoded = GridSelection.decode(original.encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded, original)
    }

    func testSelectionDecodeInvalid() {
        XCTAssertNil(GridSelection.decode(""))
        XCTAssertNil(GridSelection.decode("1,2"))
        XCTAssertNil(GridSelection.decode("a,b-c,d"))
    }

    // MARK: - GridCalculator: frame(for:in:)

    func testFullScreenSelection_6x4() {
        let calc   = GridCalculator(columns: 6, rows: 4)
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let sel    = GridSelection(startCell: GridCell(col: 0, row: 0),
                                   endCell:   GridCell(col: 5, row: 3))
        let frame  = calc.frame(for: sel, in: screen)
        XCTAssertEqual(frame, screen, accuracy: 0.001)
    }

    func testLeftHalfSelection_6x4() {
        let calc   = GridCalculator(columns: 6, rows: 4)
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        // Columns 0-2, all rows
        let sel    = GridSelection(startCell: GridCell(col: 0, row: 0),
                                   endCell:   GridCell(col: 2, row: 3))
        let frame  = calc.frame(for: sel, in: screen)
        XCTAssertEqual(frame.width,  600,  accuracy: 0.001)
        XCTAssertEqual(frame.height, 800,  accuracy: 0.001)
        XCTAssertEqual(frame.minX,   0,    accuracy: 0.001)
    }

    func testRightThirdSelection_6x4() {
        let calc   = GridCalculator(columns: 6, rows: 4)
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        // Columns 4-5, rows 0-3
        let sel    = GridSelection(startCell: GridCell(col: 4, row: 0),
                                   endCell:   GridCell(col: 5, row: 3))
        let frame  = calc.frame(for: sel, in: screen)
        XCTAssertEqual(frame.width,  400, accuracy: 0.001)
        XCTAssertEqual(frame.minX,   800, accuracy: 0.001)
    }

    func testTopLeftQuarterSelection() {
        let calc   = GridCalculator(columns: 4, rows: 4)
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let sel    = GridSelection(startCell: GridCell(col: 0, row: 0),
                                   endCell:   GridCell(col: 1, row: 1))
        let frame  = calc.frame(for: sel, in: screen)
        XCTAssertEqual(frame.width,  600, accuracy: 0.001)
        XCTAssertEqual(frame.height, 400, accuracy: 0.001)
        XCTAssertEqual(frame.minX,   0,   accuracy: 0.001)
        XCTAssertEqual(frame.minY,   0,   accuracy: 0.001)
    }

    func testFrameWithGap() {
        let calc   = GridCalculator(columns: 2, rows: 2, gapPixels: 10)
        let screen = CGRect(x: 0, y: 0, width: 810, height: 410)
        let selTopLeft = GridSelection(startCell: GridCell(col: 0, row: 0),
                                       endCell:   GridCell(col: 0, row: 0))
        let frame = calc.frame(for: selTopLeft, in: screen)
        // Cell width = (810 - 10) / 2 = 400
        // Cell height = (410 - 10) / 2 = 200
        XCTAssertEqual(frame.width,  400, accuracy: 0.001)
        XCTAssertEqual(frame.height, 200, accuracy: 0.001)
        XCTAssertEqual(frame.minX,   0,   accuracy: 0.001)
        XCTAssertEqual(frame.minY,   0,   accuracy: 0.001)
    }

    func testBottomRightCellWithGap() {
        let calc   = GridCalculator(columns: 2, rows: 2, gapPixels: 10)
        let screen = CGRect(x: 0, y: 0, width: 810, height: 410)
        let sel    = GridSelection(startCell: GridCell(col: 1, row: 1),
                                   endCell:   GridCell(col: 1, row: 1))
        let frame  = calc.frame(for: sel, in: screen)
        XCTAssertEqual(frame.width,  400, accuracy: 0.001)
        XCTAssertEqual(frame.height, 200, accuracy: 0.001)
        XCTAssertEqual(frame.minX,   410, accuracy: 0.001)    // 400 + 10 gap
        XCTAssertEqual(frame.minY,   210, accuracy: 0.001)    // 200 + 10 gap
    }

    // MARK: - GridCalculator: cell(at:in:)

    func testCellAtOrigin() {
        let calc   = GridCalculator(columns: 6, rows: 4)
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let cell   = calc.cell(at: CGPoint(x: 1, y: 1), in: screen)
        XCTAssertEqual(cell, GridCell(col: 0, row: 0))
    }

    func testCellAtCenter() {
        let calc   = GridCalculator(columns: 6, rows: 4)
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let cell   = calc.cell(at: CGPoint(x: 600, y: 400), in: screen)
        XCTAssertEqual(cell, GridCell(col: 3, row: 2))
    }

    func testCellAtBottomRight() {
        let calc   = GridCalculator(columns: 6, rows: 4)
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let cell   = calc.cell(at: CGPoint(x: 1199, y: 799), in: screen)
        XCTAssertEqual(cell, GridCell(col: 5, row: 3))
    }

    func testCellOutsideFrame() {
        let calc   = GridCalculator(columns: 6, rows: 4)
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        XCTAssertNil(calc.cell(at: CGPoint(x: -1, y: 400), in: screen))
        XCTAssertNil(calc.cell(at: CGPoint(x: 600, y: 801), in: screen))
    }

    func testCellAtWithNonZeroOrigin() {
        let calc   = GridCalculator(columns: 2, rows: 2)
        let screen = CGRect(x: 100, y: 200, width: 400, height: 300)
        let cell   = calc.cell(at: CGPoint(x: 350, y: 350), in: screen)
        // x=350 in screen starting at x=100 → localX=250 → col = 250 / 200 = 1
        // y=350 in screen starting at y=200 → localY=150 → row = 150 / 150 = 1
        XCTAssertEqual(cell, GridCell(col: 1, row: 1))
    }

    // MARK: - GridConfig clamping

    func testGridConfigClamps() {
        let c1 = GridConfig(columns: 0, rows: 0)
        XCTAssertEqual(c1.columns, 1)
        XCTAssertEqual(c1.rows,    1)

        let c2 = GridConfig(columns: 99, rows: 99)
        XCTAssertEqual(c2.columns, 20)
        XCTAssertEqual(c2.rows,    20)
    }
}

// Precision helper
private func XCTAssertEqual(_ a: CGFloat, _ b: CGFloat, accuracy: CGFloat,
                             _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(Double(a), Double(b), accuracy: Double(accuracy), message, file: file, line: line)
}

private func XCTAssertEqual(_ a: CGRect, _ b: CGRect, accuracy: CGFloat,
                             _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(a.minX,   b.minX,   accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(a.minY,   b.minY,   accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(a.width,  b.width,  accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(a.height, b.height, accuracy: accuracy, file: file, line: line)
}
