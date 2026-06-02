import Foundation
import CoreGraphics

// MARK: - GridConfig
/// Per-display grid configuration, persisted in SQLite.
public struct GridConfig: Sendable, Codable, Equatable {
    public var columns:    Int
    public var rows:       Int
    public var gapPixels:  CGFloat

    public init(columns: Int = 6, rows: Int = 4, gapPixels: CGFloat = 0) {
        self.columns   = max(1, min(columns,   20))
        self.rows      = max(1, min(rows,      20))
        self.gapPixels = max(0, gapPixels)
    }

    public static let `default` = GridConfig(columns: 6, rows: 4, gapPixels: 0)
}

// MARK: - DisplayProfile
/// A saved named display profile (arrangement identifier + human name).
public struct DisplayProfile: Sendable, Codable, Identifiable {
    public var id:         Int
    public var profileKey: String   // e.g. "603777345+603777346"
    public var name:       String   // e.g. "Desk Setup"
    public var createdAt:  Date

    public init(id: Int = 0, profileKey: String, name: String, createdAt: Date = Date()) {
        self.id         = id
        self.profileKey = profileKey
        self.name       = name
        self.createdAt  = createdAt
    }
}

// MARK: - NamedLayout
/// A saved named layout: a mapping of app bundle IDs to grid selections per display.
public struct NamedLayout: Sendable, Codable, Identifiable {
    public var id:        Int
    public var name:      String
    public var hotkey:    String?
    public var entries:   [LayoutEntry]
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: Int = 0, name: String, hotkey: String? = nil, entries: [LayoutEntry] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id        = id
        self.name      = name
        self.hotkey    = hotkey
        self.entries   = entries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct LayoutEntry: Sendable, Codable {
    public var bundleID:  String          // e.g. "com.apple.Safari"
    public var displayID: String
    public var selection: GridSelection

    public init(bundleID: String, displayID: String, selection: GridSelection) {
        self.bundleID  = bundleID
        self.displayID = displayID
        self.selection = selection
    }
}

// MARK: - PerAppRule
/// When this app launches/focuses, snap it to this grid selection on the given display.
public struct PerAppRule: Sendable, Codable, Identifiable {
    public var id:        Int
    public var bundleID:  String
    public var displayID: String
    public var selection: GridSelection
    public var trigger:   RuleTrigger

    public enum RuleTrigger: String, Codable, Sendable {
        case onLaunch   = "launch"
        case onFocus    = "focus"
    }

    public init(id: Int = 0, bundleID: String, displayID: String, selection: GridSelection, trigger: RuleTrigger = .onLaunch) {
        self.id        = id
        self.bundleID  = bundleID
        self.displayID = displayID
        self.selection = selection
        self.trigger   = trigger
    }
}

// MARK: - SavedShortcut
/// A keyboard shortcut (stored as Carbon key combo string) mapped to a grid selection.
public struct SavedShortcut: Sendable, Codable, Identifiable {
    public var id:         Int
    public var keyCombo:   String          // e.g. "cmd+shift+1"
    public var selection:  GridSelection
    public var displayID:  String?
    public var name:       String?
    public var profileKey: String?         // nil = applies to all profiles (GH#4)

    public init(id: Int = 0, keyCombo: String, selection: GridSelection,
                displayID: String? = nil, name: String? = nil, profileKey: String? = nil) {
        self.id         = id
        self.keyCombo   = keyCombo
        self.selection  = selection
        self.displayID  = displayID
        self.name       = name
        self.profileKey = profileKey
    }
}

// MARK: - SnapshotEntry
/// One window's pixel-exact frame, captured at snapshot time.
/// Frame stored as individual doubles so Codable works without CGRect extension.
/// x/y are in global screen coordinates, bottom-left origin (matches AX API).
public struct SnapshotEntry: Sendable, Codable {
    public var bundleID:  String
    public var displayID: String
    public var x:         Double
    public var y:         Double
    public var width:     Double
    public var height:    Double

    /// Reconstituted CGRect (global coords, bottom-left origin).
    public var frame: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    public init(bundleID: String, displayID: String, frame: CGRect) {
        self.bundleID  = bundleID
        self.displayID = displayID
        self.x         = Double(frame.origin.x)
        self.y         = Double(frame.origin.y)
        self.width     = Double(frame.size.width)
        self.height    = Double(frame.size.height)
    }
}

// MARK: - LayoutSnapshot
/// A named, timestamped snapshot of all visible window positions (pixel-exact).
/// Unlike NamedLayout (grid-aligned), snapshots store raw CGRect frames.
public struct LayoutSnapshot: Sendable, Codable, Identifiable {
    public var id:        Int
    public var name:      String
    public var entries:   [SnapshotEntry]
    public var createdAt: Date

    public init(id: Int = 0, name: String, entries: [SnapshotEntry] = [], createdAt: Date = Date()) {
        self.id        = id
        self.name      = name
        self.entries   = entries
        self.createdAt = createdAt
    }
}
