import XCTest
@testable import GridForgeCore

final class DatabaseTests: XCTestCase {

    var db: DatabaseManager!
    private var tempPath: String!

    override func setUpWithError() throws {
        db = DatabaseManager.shared
        // Use an in-memory DB for complete test isolation — no file state leakage
        try db.openInMemory()
    }

    override func tearDownWithError() throws {
        db.close()
    }

    // MARK: - Grid Config

    func testSaveAndLoadDefaultConfig() {
        let config = GridConfig(columns: 8, rows: 5, gapPixels: 4)
        db.saveGridConfig(config, displayID: "test_display_1")
        let loaded = db.loadGridConfig(displayID: "test_display_1")
        XCTAssertEqual(loaded.columns,   8)
        XCTAssertEqual(loaded.rows,      5)
        XCTAssertEqual(loaded.gapPixels, 4, accuracy: 0.001)
    }

    func testLoadMissingConfigReturnsDefault() {
        let loaded = db.loadGridConfig(displayID: "nonexistent_display_xyz")
        XCTAssertEqual(loaded.columns,   GridConfig.default.columns)
        XCTAssertEqual(loaded.rows,      GridConfig.default.rows)
        XCTAssertEqual(loaded.gapPixels, GridConfig.default.gapPixels, accuracy: 0.001)
    }

    func testConfigUpsert() {
        db.saveGridConfig(GridConfig(columns: 4, rows: 4), displayID: "upsert_test")
        db.saveGridConfig(GridConfig(columns: 6, rows: 6), displayID: "upsert_test")
        let loaded = db.loadGridConfig(displayID: "upsert_test")
        XCTAssertEqual(loaded.columns, 6)
        XCTAssertEqual(loaded.rows,    6)
    }

    // MARK: - Layouts

    func testSaveAndLoadLayout() throws {
        let sel    = GridSelection(startCell: GridCell(col: 0, row: 0),
                                   endCell:   GridCell(col: 2, row: 1))
        let entry  = LayoutEntry(bundleID: "com.apple.Safari",
                                 displayID: "display_1",
                                 selection: sel)
        let layout = NamedLayout(name: "TestLayout_\(UUID())", hotkey: "cmd+1", entries: [entry])

        try db.saveLayout(layout)
        let all = db.loadLayouts()
        let found = all.first(where: { $0.name == layout.name })
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.hotkey, "cmd+1")
        XCTAssertEqual(found?.entries.count, 1)
        XCTAssertEqual(found?.entries.first?.bundleID, "com.apple.Safari")
    }

    func testLayoutUpsert() throws {
        let name = "UpsertLayout_\(UUID())"
        try db.saveLayout(NamedLayout(name: name, hotkey: "cmd+1"))
        try db.saveLayout(NamedLayout(name: name, hotkey: "cmd+2"))
        let found = db.loadLayouts().first(where: { $0.name == name })
        XCTAssertEqual(found?.hotkey, "cmd+2")
    }

    func testDeleteLayout() throws {
        let name = "DeleteMe_\(UUID())"
        try db.saveLayout(NamedLayout(name: name))
        db.deleteLayout(name: name)
        let found = db.loadLayouts().first(where: { $0.name == name })
        XCTAssertNil(found)
    }

    // MARK: - Per-App Rules

    func testSaveAndLoadPerAppRule() {
        let sel  = GridSelection(startCell: GridCell(col: 0, row: 0),
                                 endCell:   GridCell(col: 2, row: 3))
        let rule = PerAppRule(bundleID: "com.test.app_\(UUID())",
                              displayID: "display_1",
                              selection: sel,
                              trigger:  .onLaunch)
        db.savePerAppRule(rule)
        let rules  = db.loadPerAppRules()
        let found  = rules.first(where: { $0.bundleID == rule.bundleID })
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.selection, sel)
        XCTAssertEqual(found?.trigger,   .onLaunch)
    }

    // MARK: - Session Log (smoke test — no read-back needed, just no crash)

    func testSessionLogDoesNotThrow() {
        let sel = GridSelection(startCell: GridCell(col: 0, row: 0),
                                endCell:   GridCell(col: 2, row: 1))
        db.logAction(action: "test_snap", displayID: "display_1", selection: sel,
                     appBundle: "com.apple.Safari", layoutName: nil, shortcut: nil)
        // If we get here without crashing, pass
    }

    // MARK: - Open/Close idempotency

    func testCloseAndReopenIsIdempotent() throws {
        db.close()
        XCTAssertFalse(db.isOpen)
        try db.openInMemory()
        XCTAssertTrue(db.isOpen)
        // Basic sanity — loadGridConfig should work after reopen
        let _ = db.loadGridConfig(displayID: "reopen_test")
    }
}

private func XCTAssertEqual(_ a: CGFloat, _ b: CGFloat, accuracy: CGFloat,
                             file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(Double(a), Double(b), accuracy: Double(accuracy), file: file, line: line)
}
