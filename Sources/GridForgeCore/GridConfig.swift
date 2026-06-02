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
    public var id:        Int
    public var keyCombo:  String          // e.g. "cmd+shift+1"
    public var selection: GridSelection
    public var displayID: String?
    public var name:      String?

    public init(id: Int = 0, keyCombo: String, selection: GridSelection, displayID: String? = nil, name: String? = nil) {
        self.id        = id
        self.keyCombo  = keyCombo
        self.selection = selection
        self.displayID = displayID
        self.name      = name
    }
}
