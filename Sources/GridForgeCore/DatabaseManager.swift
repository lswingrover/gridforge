import Foundation
import SQLite3

/// Thread-safe SQLite wrapper. All writes are serialised on a private queue.
/// Reads use a shared concurrent queue with barriers for writes.
public final class DatabaseManager: @unchecked Sendable {

    public static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.lswingrover.gridforge.db",
                                      attributes: .concurrent)
    public private(set) var isOpen = false

    private init() {}

    // MARK: - Lifecycle

    public func open() throws {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GridForge")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("gridforge.db").path
        var localDB: OpaquePointer?
        guard sqlite3_open(path, &localDB) == SQLITE_OK, let localDB else {
            throw GridForgeDBError.openFailed(path)
        }
        db = localDB
        isOpen = true
        try applyMigrations()
    }

    /// Opens an isolated in-memory database — for use in unit tests ONLY.
    public func openInMemory() throws {
        if isOpen { close() }
        var localDB: OpaquePointer?
        guard sqlite3_open(":memory:", &localDB) == SQLITE_OK, let localDB else {
            throw GridForgeDBError.openFailed(":memory:")
        }
        db = localDB
        isOpen = true
        try applyMigrations()
    }

    public func close() {
        queue.sync(flags: .barrier) {
            sqlite3_close(self.db)
            self.db = nil
            self.isOpen = false
        }
    }

    // MARK: - Migrations

    private func applyMigrations() throws {
        // Migration 0001 — initial schema (all CREATE TABLE IF NOT EXISTS, idempotent)
        let migrations: [String] = [
            """
            CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY)
            """,
            """
            INSERT OR IGNORE INTO schema_version VALUES (1)
            """,
            """
            CREATE TABLE IF NOT EXISTS grid_config (
                display_id  TEXT PRIMARY KEY,
                columns     INTEGER NOT NULL DEFAULT 6,
                rows        INTEGER NOT NULL DEFAULT 4,
                gap_pixels  REAL    NOT NULL DEFAULT 0.0,
                updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS shortcuts (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                key_combo   TEXT    NOT NULL UNIQUE,
                col_start   INTEGER NOT NULL,
                row_start   INTEGER NOT NULL,
                col_end     INTEGER NOT NULL,
                row_end     INTEGER NOT NULL,
                display_id  TEXT,
                name        TEXT,
                created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS layouts (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                name        TEXT    NOT NULL UNIQUE,
                hotkey      TEXT,
                data        TEXT    NOT NULL DEFAULT '[]',
                created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
                updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS per_app_rules (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                bundle_id   TEXT    NOT NULL,
                display_id  TEXT    NOT NULL,
                selection   TEXT    NOT NULL,
                trigger     TEXT    NOT NULL DEFAULT 'launch',
                UNIQUE(bundle_id, display_id)
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS session_log (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                action      TEXT    NOT NULL,
                display_id  TEXT,
                selection   TEXT,
                app_bundle  TEXT,
                layout_name TEXT,
                shortcut    TEXT,
                ts          TEXT    NOT NULL DEFAULT (datetime('now'))
            )
            """
        ]
        for sql in migrations {
            try exec(sql)
        }

        // Migration 0002 — display profiles (idempotent via IF NOT EXISTS + column check)
        try applyMigration0002()
        // Migration 0003 — layout snapshots (GH#7)
        try applyMigration0003()
    }

    private func applyMigration0002() throws {
        // Named display profiles registry
        try exec("""
            CREATE TABLE IF NOT EXISTS display_profiles (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                profile_key TEXT    NOT NULL UNIQUE,
                name        TEXT    NOT NULL,
                created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
            )
        """)
        // Per-profile grid config overrides (separate from universal grid_config)
        try exec("""
            CREATE TABLE IF NOT EXISTS display_profile_configs (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                display_id  TEXT    NOT NULL,
                profile_key TEXT    NOT NULL,
                columns     INTEGER NOT NULL DEFAULT 6,
                rows        INTEGER NOT NULL DEFAULT 4,
                gap_pixels  REAL    NOT NULL DEFAULT 0.0,
                updated_at  TEXT    NOT NULL DEFAULT (datetime('now')),
                UNIQUE(display_id, profile_key)
            )
        """)
        // Add profile_key column to shortcuts (GH#4 — nil = applies to all profiles)
        if !columnExists(table: "shortcuts", column: "profile_key") {
            try exec("ALTER TABLE shortcuts ADD COLUMN profile_key TEXT")
        }
    }

    private func applyMigration0003() throws {
        try exec(
            """
            CREATE TABLE IF NOT EXISTS snapshots (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                name       TEXT    NOT NULL UNIQUE,
                data       TEXT    NOT NULL DEFAULT '[]',
                created_at TEXT    NOT NULL DEFAULT (datetime('now'))
            )
            """
        )
    }

        // MARK: - Grid Config

    /// Load grid config for a display, optionally scoped to a display profile.
    /// If profileKey is provided, checks display_profile_configs first;
    /// falls back to the universal grid_config row.
    public func loadGridConfig(displayID: String, profileKey: String? = nil) -> GridConfig {
        // 1. Try profile-specific override
        if let key = profileKey, !key.isEmpty {
            let profileSQL = """
                SELECT columns, rows, gap_pixels
                FROM display_profile_configs
                WHERE display_id = ? AND profile_key = ?
            """
            var found: GridConfig?
            queue.sync {
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                guard sqlite3_prepare_v2(db, profileSQL, -1, &stmt, nil) == SQLITE_OK else { return }
                bind(stmt, 1, displayID)
                bind(stmt, 2, key)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    found = GridConfig(
                        columns:   Int(sqlite3_column_int(stmt, 0)),
                        rows:      Int(sqlite3_column_int(stmt, 1)),
                        gapPixels: CGFloat(sqlite3_column_double(stmt, 2))
                    )
                }
            }
            if let f = found { return f }
        }
        // 2. Fall back to universal config
        return loadUniversalGridConfig(displayID: displayID)
    }

    private func loadUniversalGridConfig(displayID: String) -> GridConfig {
        var config = GridConfig.default
        let sql = "SELECT columns, rows, gap_pixels FROM grid_config WHERE display_id = ?"
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            bind(stmt, 1, displayID)
            if sqlite3_step(stmt) == SQLITE_ROW {
                config.columns   = Int(sqlite3_column_int(stmt, 0))
                config.rows      = Int(sqlite3_column_int(stmt, 1))
                config.gapPixels = CGFloat(sqlite3_column_double(stmt, 2))
            }
        }
        return config
    }

    /// Save grid config.
    /// - If profileKey is nil/empty: saves to universal grid_config (existing behaviour).
    /// - If profileKey is provided: saves to display_profile_configs (profile-specific override).
    public func saveGridConfig(_ config: GridConfig, displayID: String, profileKey: String? = nil) {
        if let key = profileKey, !key.isEmpty {
            saveProfileGridConfig(config, displayID: displayID, profileKey: key)
        } else {
            saveUniversalGridConfig(config, displayID: displayID)
        }
    }

    private func saveUniversalGridConfig(_ config: GridConfig, displayID: String) {
        let sql = """
            INSERT INTO grid_config (display_id, columns, rows, gap_pixels)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(display_id) DO UPDATE SET
                columns    = excluded.columns,
                rows       = excluded.rows,
                gap_pixels = excluded.gap_pixels,
                updated_at = datetime('now')
        """
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            bind(stmt, 1, displayID)
            sqlite3_bind_int   (stmt, 2, Int32(config.columns))
            sqlite3_bind_int   (stmt, 3, Int32(config.rows))
            sqlite3_bind_double(stmt, 4, Double(config.gapPixels))
            sqlite3_step(stmt)
        }
    }

    private func saveProfileGridConfig(_ config: GridConfig, displayID: String, profileKey: String) {
        let sql = """
            INSERT INTO display_profile_configs (display_id, profile_key, columns, rows, gap_pixels)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(display_id, profile_key) DO UPDATE SET
                columns    = excluded.columns,
                rows       = excluded.rows,
                gap_pixels = excluded.gap_pixels,
                updated_at = datetime('now')
        """
        // Note: 5 bind positions (display_id, profile_key, columns, rows, gap_pixels)
        let sql5 = """
            INSERT INTO display_profile_configs (display_id, profile_key, columns, rows, gap_pixels)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(display_id, profile_key) DO UPDATE SET
                columns    = excluded.columns,
                rows       = excluded.rows,
                gap_pixels = excluded.gap_pixels,
                updated_at = datetime('now')
        """
        _ = sql  // suppress unused warning
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql5, -1, &stmt, nil) == SQLITE_OK else { return }
            bind(stmt, 1, displayID)
            bind(stmt, 2, profileKey)
            sqlite3_bind_int   (stmt, 3, Int32(config.columns))
            sqlite3_bind_int   (stmt, 4, Int32(config.rows))
            sqlite3_bind_double(stmt, 5, Double(config.gapPixels))
            sqlite3_step(stmt)
        }
    }

    // MARK: - Display Profiles

    public func saveDisplayProfile(key: String, name: String) {
        let sql = """
            INSERT INTO display_profiles (profile_key, name)
            VALUES (?, ?)
            ON CONFLICT(profile_key) DO UPDATE SET name = excluded.name
        """
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            bind(stmt, 1, key)
            bind(stmt, 2, name)
            sqlite3_step(stmt)
        }
    }

    public func loadDisplayProfiles() -> [DisplayProfile] {
        var results: [DisplayProfile] = []
        let sql = "SELECT id, profile_key, name, created_at FROM display_profiles ORDER BY created_at"
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id         = Int(sqlite3_column_int(stmt, 0))
                let profileKey = String(cString: sqlite3_column_text(stmt, 1))
                let name       = String(cString: sqlite3_column_text(stmt, 2))
                results.append(DisplayProfile(id: id, profileKey: profileKey, name: name))
            }
        }
        return results
    }

    public func deleteDisplayProfile(key: String) {
        // Delete profile and its config overrides
        let deleteCfg = "DELETE FROM display_profile_configs WHERE profile_key = ?"
        let deleteProf = "DELETE FROM display_profiles WHERE profile_key = ?"
        queue.sync(flags: .barrier) {
            for sql in [deleteCfg, deleteProf] {
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }
                self.bind(stmt, 1, key)
                sqlite3_step(stmt)
            }
        }
    }

    // MARK: - Shortcuts

    public func saveShortcut(_ shortcut: SavedShortcut) throws {
        // ON CONFLICT updates all mutable fields; key_combo is the unique key.
        let sql = "INSERT INTO shortcuts (key_combo, col_start, row_start, col_end, row_end, display_id, name, profile_key) " +
                  "VALUES (?, ?, ?, ?, ?, ?, ?, ?) " +
                  "ON CONFLICT(key_combo) DO UPDATE SET " +
                  "  col_start   = excluded.col_start, " +
                  "  row_start   = excluded.row_start, " +
                  "  col_end     = excluded.col_end, " +
                  "  row_end     = excluded.row_end, " +
                  "  display_id  = excluded.display_id, " +
                  "  name        = excluded.name, " +
                  "  profile_key = excluded.profile_key"
        try queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw GridForgeDBError.prepareFailed(sql)
            }
            let sel = shortcut.selection
            bind(stmt, 1, shortcut.keyCombo)
            sqlite3_bind_int(stmt, 2, Int32(sel.normalizedStartCol))
            sqlite3_bind_int(stmt, 3, Int32(sel.normalizedStartRow))
            sqlite3_bind_int(stmt, 4, Int32(sel.normalizedEndCol))
            sqlite3_bind_int(stmt, 5, Int32(sel.normalizedEndRow))
            bind(stmt, 6, shortcut.displayID)
            bind(stmt, 7, shortcut.name)
            bind(stmt, 8, shortcut.profileKey)
            let result = sqlite3_step(stmt)
            if result != SQLITE_DONE && result != SQLITE_ROW {
                let msg = String(cString: sqlite3_errmsg(self.db))
                throw GridForgeDBError.execFailed("saveShortcut step (\(result)): \(msg)")
            }
        }
    }

    public func loadShortcuts() -> [SavedShortcut] {
        var results: [SavedShortcut] = []
        let sql = "SELECT id, key_combo, col_start, row_start, col_end, row_end, display_id, name, profile_key " +
                  "FROM shortcuts ORDER BY id"
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id        = Int(sqlite3_column_int(stmt, 0))
                let keyCombo  = String(cString: sqlite3_column_text(stmt, 1))
                let colStart  = Int(sqlite3_column_int(stmt, 2))
                let rowStart  = Int(sqlite3_column_int(stmt, 3))
                let colEnd    = Int(sqlite3_column_int(stmt, 4))
                let rowEnd    = Int(sqlite3_column_int(stmt, 5))
                let displayID  = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let name       = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let profileKey = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                let sel = GridSelection(
                    startCell: GridCell(col: colStart, row: rowStart),
                    endCell:   GridCell(col: colEnd,   row: rowEnd)
                )
                results.append(SavedShortcut(
                    id:         id,
                    keyCombo:   keyCombo,
                    selection:  sel,
                    displayID:  displayID,
                    name:       name,
                    profileKey: profileKey
                ))
            }
        }
        return results
    }

    public func deleteShortcut(id: Int) {
        let sql = "DELETE FROM shortcuts WHERE id = ?"
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_int(stmt, 1, Int32(id))
            sqlite3_step(stmt)
        }
    }

    // MARK: - Layouts

    public func saveLayout(_ layout: NamedLayout) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(layout.entries)
        let json = String(data: data, encoding: .utf8) ?? "[]"
        let sql = """
            INSERT INTO layouts (name, hotkey, data)
            VALUES (?, ?, ?)
            ON CONFLICT(name) DO UPDATE SET
                hotkey     = excluded.hotkey,
                data       = excluded.data,
                updated_at = datetime('now')
        """
        try queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw GridForgeDBError.prepareFailed(sql)
            }
            bind(stmt, 1, layout.name)
            bind(stmt, 2, layout.hotkey)
            bind(stmt, 3, json)
            let stepResult = sqlite3_step(stmt)
            if stepResult != SQLITE_DONE && stepResult != SQLITE_ROW {
                let errMsg = String(cString: sqlite3_errmsg(self.db))
                throw GridForgeDBError.execFailed("saveLayout step failed (\(stepResult)): \(errMsg)")
            }
        }
    }

    public func loadLayouts() -> [NamedLayout] {
        var results: [NamedLayout] = []
        let sql = "SELECT id, name, hotkey, data, created_at, updated_at FROM layouts ORDER BY name"
        let decoder = JSONDecoder()
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id      = Int(sqlite3_column_int(stmt, 0))
                let name    = String(cString: sqlite3_column_text(stmt, 1))
                let hotkey  = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                let dataStr = String(cString: sqlite3_column_text(stmt, 3))
                let entries = (try? decoder.decode([LayoutEntry].self, from: Data(dataStr.utf8))) ?? []
                results.append(NamedLayout(id: id, name: name, hotkey: hotkey, entries: entries))
            }
        }
        return results
    }

    public func deleteLayout(name: String) {
        let sql = "DELETE FROM layouts WHERE name = ?"
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            bind(stmt, 1, name)
            sqlite3_step(stmt)
        }
    }

    // MARK: - Session Log

    public func logAction(
        action: String,
        displayID: String? = nil,
        selection: GridSelection? = nil,
        appBundle: String? = nil,
        layoutName: String? = nil,
        shortcut: String? = nil
    ) {
        let sql = """
            INSERT INTO session_log (action, display_id, selection, app_bundle, layout_name, shortcut)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            self.bind(stmt, 1, action)
            self.bind(stmt, 2, displayID)
            self.bind(stmt, 3, selection?.encoded)
            self.bind(stmt, 4, appBundle)
            self.bind(stmt, 5, layoutName)
            self.bind(stmt, 6, shortcut)
            sqlite3_step(stmt)
        }
    }

    // MARK: - Per-App Rules

    public func savePerAppRule(_ rule: PerAppRule) {
        let sql = """
            INSERT INTO per_app_rules (bundle_id, display_id, selection, trigger)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(bundle_id, display_id) DO UPDATE SET
                selection = excluded.selection,
                trigger   = excluded.trigger
        """
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            bind(stmt, 1, rule.bundleID)
            bind(stmt, 2, rule.displayID)
            bind(stmt, 3, rule.selection.encoded)
            bind(stmt, 4, rule.trigger.rawValue)
            let stepResult = sqlite3_step(stmt)
            if stepResult != SQLITE_DONE && stepResult != SQLITE_ROW {
                NSLog("GridForgeDB savePerAppRule step failed (%d): %s",
                      stepResult, sqlite3_errmsg(self.db))
            }
        }
    }

    public func loadPerAppRules() -> [PerAppRule] {
        var results: [PerAppRule] = []
        let sql = "SELECT id, bundle_id, display_id, selection, trigger FROM per_app_rules"
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id       = Int(sqlite3_column_int(stmt, 0))
                let bundle   = String(cString: sqlite3_column_text(stmt, 1))
                let display  = String(cString: sqlite3_column_text(stmt, 2))
                let selStr   = String(cString: sqlite3_column_text(stmt, 3))
                let trigStr  = String(cString: sqlite3_column_text(stmt, 4))
                guard let sel = GridSelection.decode(selStr) else { continue }
                let trigger  = PerAppRule.RuleTrigger(rawValue: trigStr) ?? .onLaunch
                results.append(PerAppRule(id: id, bundleID: bundle, displayID: display,
                                          selection: sel, trigger: trigger))
            }
        }
        return results
    }


    public func deletePerAppRule(id: Int) {
        let sql = "DELETE FROM per_app_rules WHERE id = ?"
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_int(stmt, 1, Int32(id))
            sqlite3_step(stmt)
        }
    }

    // MARK: - Snapshots

    public func saveSnapshot(_ snapshot: LayoutSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot.entries),
              let json = String(data: data, encoding: .utf8) else { return }
        let df = ISO8601DateFormatter()
        let dateStr = df.string(from: snapshot.createdAt)
        let sql = """
            INSERT INTO snapshots (name, data, created_at)
            VALUES (?, ?, ?)
            ON CONFLICT(name) DO UPDATE SET
                data       = excluded.data,
                created_at = excluded.created_at
        """
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            bind(stmt, 1, snapshot.name)
            bind(stmt, 2, json)
            bind(stmt, 3, dateStr)
            let result = sqlite3_step(stmt)
            if result != SQLITE_DONE && result != SQLITE_ROW {
                NSLog("GridForgeDB saveSnapshot failed (%d): %s", result, sqlite3_errmsg(self.db))
            }
        }
    }

    public func loadSnapshots() -> [LayoutSnapshot] {
        var results: [LayoutSnapshot] = []
        let sql = "SELECT id, name, data, created_at FROM snapshots ORDER BY created_at DESC"
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let df = ISO8601DateFormatter()
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id      = Int(sqlite3_column_int(stmt, 0))
                let name    = String(cString: sqlite3_column_text(stmt, 1))
                let json    = String(cString: sqlite3_column_text(stmt, 2))
                let dateStr = String(cString: sqlite3_column_text(stmt, 3))
                let date    = df.date(from: dateStr) ?? Date()
                let entries = (try? decoder.decode([SnapshotEntry].self,
                                                    from: Data(json.utf8))) ?? []
                results.append(LayoutSnapshot(id: id, name: name,
                                               entries: entries, createdAt: date))
            }
        }
        return results
    }

    public func deleteSnapshot(id: Int) {
        let sql = "DELETE FROM snapshots WHERE id = ?"
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_int(stmt, 1, Int32(id))
            sqlite3_step(stmt)
        }
    }

        // MARK: - Helpers

    private func exec(_ sql: String) throws {
        try queue.sync(flags: .barrier) {
            var err: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
                let msg = err.map { String(cString: $0) } ?? "unknown"
                sqlite3_free(err)
                throw GridForgeDBError.execFailed(msg)
            }
        }
    }

    /// Routes all SQLite text binds through a single site (GH#14).
    /// Uses SQLITE_TRANSIENT so SQLite copies the string immediately --
    /// safe regardless of Swift-string lifetime (fixes SQLITE_STATIC UB).
    private func bind(_ stmt: OpaquePointer?, _ idx: Int32, _ val: String?) {
        guard let str = val else { sqlite3_bind_null(stmt, idx); return }
        let transient = unsafeBitCast(-1 as Int,
                                      to: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?.self)
        str.withCString { cStr in
            sqlite3_bind_text(stmt, idx, cStr, -1, transient)
        }
    }

    /// Returns true if the given column exists in the given table (GH#4 — idempotent migrations).
    private func columnExists(table: String, column: String) -> Bool {
        var found = false
        let sql = "PRAGMA table_info(\(table))"
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            while sqlite3_step(stmt) == SQLITE_ROW {
                // PRAGMA table_info columns: cid, name, type, notnull, dflt_value, pk
                if let namePtr = sqlite3_column_text(stmt, 1),
                   String(cString: namePtr) == column {
                    found = true
                    return
                }
            }
        }
        return found
    }
}

// MARK: - Errors
public enum GridForgeDBError: Error, CustomStringConvertible {
    case openFailed(String)
    case prepareFailed(String)
    case execFailed(String)

    public var description: String {
        switch self {
        case .openFailed(let p):    return "GridForgeDB: failed to open \(p)"
        case .prepareFailed(let s): return "GridForgeDB: prepare failed for \(s)"
        case .execFailed(let m):    return "GridForgeDB: exec failed: \(m)"
        }
    }
}
