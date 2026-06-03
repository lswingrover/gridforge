import XCTest
@testable import GridForgeCore

final class DatabaseTests: XCTestCase {

    var db: DatabaseManager!

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

    // MARK: - Display Profiles (GH#4)

    func testMigration0002_tablesExist() {
        // If migration 0002 ran, display_profiles and display_profile_configs exist.
        // Saving a display profile without error confirms both tables are present.
        db.saveDisplayProfile(key: "12345+67890", name: "Test Profile")
        let profiles = db.loadDisplayProfiles()
        XCTAssertFalse(profiles.isEmpty)
    }

    func testSaveAndLoadDisplayProfile() {
        let key  = "111+222+333"
        let name = "Triple Monitor"
        db.saveDisplayProfile(key: key, name: name)
        let profiles = db.loadDisplayProfiles()
        let found = profiles.first(where: { $0.profileKey == key })
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, name)
    }

    func testDisplayProfileUpsert() {
        let key = "aaa+bbb"
        db.saveDisplayProfile(key: key, name: "First Name")
        db.saveDisplayProfile(key: key, name: "Updated Name")
        let profiles = db.loadDisplayProfiles()
        let matches  = profiles.filter { $0.profileKey == key }
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.name, "Updated Name")
    }

    func testDeleteDisplayProfile() {
        let key = "del+test"
        db.saveDisplayProfile(key: key, name: "Delete Me")
        db.deleteDisplayProfile(key: key)
        let profiles = db.loadDisplayProfiles()
        XCTAssertNil(profiles.first(where: { $0.profileKey == key }))
    }

    func testProfileGridConfigOverridesFallback() {
        let displayID  = "disp_main"
        let profileKey = "603777345+603777346"

        // Save universal (fallback) config
        db.saveGridConfig(GridConfig(columns: 6, rows: 4), displayID: displayID)

        // Save profile-specific override
        db.saveGridConfig(GridConfig(columns: 10, rows: 8), displayID: displayID,
                          profileKey: profileKey)

        // With profileKey: should get the override
        let withProfile = db.loadGridConfig(displayID: displayID, profileKey: profileKey)
        XCTAssertEqual(withProfile.columns, 10)
        XCTAssertEqual(withProfile.rows,    8)

        // Without profileKey: should get the universal fallback
        let universal = db.loadGridConfig(displayID: displayID)
        XCTAssertEqual(universal.columns, 6)
        XCTAssertEqual(universal.rows,    4)
    }

    func testProfileGridConfigFallsBackToUniversal() {
        let displayID  = "disp_fallback"
        let profileKey = "999+888"

        // Only universal config saved — no profile-specific override
        db.saveGridConfig(GridConfig(columns: 5, rows: 3), displayID: displayID)

        // Loading with a profileKey that has no override should fall back
        let loaded = db.loadGridConfig(displayID: displayID, profileKey: profileKey)
        XCTAssertEqual(loaded.columns, 5)
        XCTAssertEqual(loaded.rows,    3)
    }

    func testProfileGridConfigMissingBothReturnsDefault() {
        let loaded = db.loadGridConfig(displayID: "no_such_display", profileKey: "no_such_profile")
        XCTAssertEqual(loaded.columns, GridConfig.default.columns)
        XCTAssertEqual(loaded.rows,    GridConfig.default.rows)
    }

    func testDeleteProfileAlsoDeletesConfigOverrides() {
        let displayID  = "disp_cascade"
        let profileKey = "cascade+test"
        db.saveDisplayProfile(key: profileKey, name: "Cascade Test")
        db.saveGridConfig(GridConfig(columns: 12, rows: 10), displayID: displayID,
                          profileKey: profileKey)

        db.deleteDisplayProfile(key: profileKey)

        // After delete, loading with this profileKey should fall back to default
        let loaded = db.loadGridConfig(displayID: displayID, profileKey: profileKey)
        XCTAssertEqual(loaded.columns, GridConfig.default.columns)
    }

    // MARK: - Shortcuts (profile_key column exists after migration 0002)

    func testShortcutWithProfileKey() throws {
        let sel = GridSelection(startCell: GridCell(col: 0, row: 0),
                                endCell:   GridCell(col: 2, row: 1))
        let sc = SavedShortcut(keyCombo: "cmd+alt+1_\(UUID())",
                               selection: sel,
                               profileKey: "111+222")
        try db.saveShortcut(sc)
        let loaded = db.loadShortcuts()
        let found  = loaded.first(where: { $0.keyCombo == sc.keyCombo })
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.profileKey, "111+222")
    }

    func testShortcutWithNilProfileKey() throws {
        let sel = GridSelection(startCell: GridCell(col: 1, row: 1),
                                endCell:   GridCell(col: 3, row: 2))
        let sc = SavedShortcut(keyCombo: "cmd+shift+2_\(UUID())",
                               selection: sel,
                               profileKey: nil)
        try db.saveShortcut(sc)
        let loaded = db.loadShortcuts()
        let found  = loaded.first(where: { $0.keyCombo == sc.keyCombo })
        XCTAssertNotNil(found)
        XCTAssertNil(found?.profileKey)
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
        let all   = db.loadLayouts()
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


    func testDeletePerAppRule() {
        let sel  = GridSelection(startCell: GridCell(col: 1, row: 1),
                                 endCell:   GridCell(col: 3, row: 2))
        let bundle = "com.test.delete_" + UUID().uuidString
        let rule = PerAppRule(bundleID: bundle, displayID: "display_1",
                              selection: sel, trigger: .onFocus)
        db.savePerAppRule(rule)
        let saved = db.loadPerAppRules().first(where: { $0.bundleID == bundle })
        XCTAssertNotNil(saved, "Rule should exist after save")
        db.deletePerAppRule(id: saved!.id)
        let after = db.loadPerAppRules().first(where: { $0.bundleID == bundle })
        XCTAssertNil(after, "Rule should be gone after delete")
    }

        // MARK: - Snapshots

    func testSaveAndLoadSnapshot() {
        let frame1 = CGRect(x: 100, y: 200, width: 800, height: 600)
        let frame2 = CGRect(x: 900, y: 50,  width: 500, height: 900)
        let entries = [
            SnapshotEntry(bundleID: "com.apple.Safari",   displayID: "display_1", frame: frame1),
            SnapshotEntry(bundleID: "com.apple.Terminal", displayID: "display_1", frame: frame2),
        ]
        let name = "TestSnap_" + UUID().uuidString
        let snap = LayoutSnapshot(name: name, entries: entries)
        db.saveSnapshot(snap)
        let loaded = db.loadSnapshots()
        let found  = loaded.first(where: { $0.name == name })
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.entries.count, 2)
        // Verify frame round-trip (within floating-point epsilon)
        if let e = found?.entries.first {
            XCTAssertEqual(e.x,      Double(frame1.origin.x),   accuracy: 0.001)
            XCTAssertEqual(e.y,      Double(frame1.origin.y),   accuracy: 0.001)
            XCTAssertEqual(e.width,  Double(frame1.size.width),  accuracy: 0.001)
            XCTAssertEqual(e.height, Double(frame1.size.height), accuracy: 0.001)
        }
    }

    func testDeleteSnapshot() {
        let name = "DeleteSnap_" + UUID().uuidString
        let snap = LayoutSnapshot(name: name, entries: [])
        db.saveSnapshot(snap)
        let saved = db.loadSnapshots().first(where: { $0.name == name })
        XCTAssertNotNil(saved, "Snapshot should exist after save")
        db.deleteSnapshot(id: saved!.id)
        let after = db.loadSnapshots().first(where: { $0.name == name })
        XCTAssertNil(after, "Snapshot should be gone after delete")
    }

        // MARK: - Session Log (smoke test — no read-back needed, just no crash)

    func testSessionLogDoesNotThrow() {
        let sel = GridSelection(startCell: GridCell(col: 0, row: 0),
                                endCell:   GridCell(col: 2, row: 1))
        db.logAction(action: "test_snap", displayID: "display_1", selection: sel,
                     appBundle: "com.apple.Safari", layoutName: nil, shortcut: nil)
        // If we get here without crashing, pass
    }

    // MARK: - Analytics (GH#11)

    func testAnalyticsEmptyDB() {
        let r = db.analyticsReport()
        XCTAssertEqual(r.totalSnaps,           0)
        XCTAssertTrue (r.topRegions.isEmpty,      "fresh DB: topRegions should be empty")
        XCTAssertTrue (r.layoutFrequency.isEmpty, "fresh DB: layoutFrequency should be empty")
        XCTAssertTrue (r.perAppUsage.isEmpty,     "fresh DB: perAppUsage should be empty")
    }

    func testAnalyticsTopRegions() {
        let sel1 = GridSelection(startCell: GridCell(col: 0, row: 0),
                                 endCell:   GridCell(col: 2, row: 1))
        let sel2 = GridSelection(startCell: GridCell(col: 3, row: 0),
                                 endCell:   GridCell(col: 5, row: 3))
        // Log sel1 three times, sel2 once
        for _ in 0..<3 { db.logAction(action: "snap", displayID: "d1", selection: sel1,
                                       appBundle: "com.apple.Safari") }
        db.logAction(action: "snap", displayID: "d1", selection: sel2,
                     appBundle: "com.apple.Terminal")
        // Give the async barrier writes time to complete before the sync read
        let exp = expectation(description: "writes flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let r = db.analyticsReport()
        XCTAssertEqual(r.totalSnaps, 4)
        XCTAssertFalse(r.topRegions.isEmpty)
        XCTAssertEqual(r.topRegions.first?.selection, sel1.encoded,
                       "highest-count region should be first")
        XCTAssertEqual(r.topRegions.first?.count, 3)
    }

    func testAnalyticsLayoutFrequency() {
        db.logAction(action: "apply_layout", layoutName: "Code Mode")
        db.logAction(action: "apply_layout", layoutName: "Code Mode")
        db.logAction(action: "apply_layout", layoutName: "Writing")
        let exp = expectation(description: "writes flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let r = db.analyticsReport()
        XCTAssertFalse(r.layoutFrequency.isEmpty)
        XCTAssertEqual(r.layoutFrequency.first?.name,  "Code Mode")
        XCTAssertEqual(r.layoutFrequency.first?.count, 2)
    }

    func testAnalyticsPerAppUsage() {
        let sel = GridSelection(startCell: GridCell(col: 0, row: 0),
                                endCell:   GridCell(col: 1, row: 1))
        db.logAction(action: "snap", displayID: "d1", selection: sel, appBundle: "com.apple.Xcode")
        db.logAction(action: "snap", displayID: "d1", selection: sel, appBundle: "com.apple.Xcode")
        db.logAction(action: "snap", displayID: "d1", selection: sel, appBundle: "com.apple.Safari")
        let exp = expectation(description: "writes flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let r = db.analyticsReport()
        XCTAssertFalse(r.perAppUsage.isEmpty)
        XCTAssertEqual(r.perAppUsage.first?.bundleID, "com.apple.Xcode")
        XCTAssertEqual(r.perAppUsage.first?.count,    2)
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
