# GridForge Roadmap

GridForge is a native macOS window placement utility with a visual grid overlay, per-app rules, layout snapshots, and a full companion API. The core feature set is shipped. This document tracks what comes next.

---

## Phase 1: Core (Complete)

- Grid overlay with configurable columns, rows, gap
- Named layouts with keyboard shortcut binding
- Per-app snap rules (onLaunch, onFocus triggers)
- Layout snapshots (full window position capture and restore)
- Display profiles (automatic config switching on monitor change)
- Stage Manager compatibility
- Companion API at localhost:14731 (snap, save layout, restore snapshot, list layouts)
- Claude companion plugin (gridforge-companion.plugin)

---

## Phase 2: Interaction Refinements

**Goal:** Make the daily workflow faster and more forgiving.

- **Edge-drag snapping** -- optional mode where dragging a window to the screen edge triggers the closest grid snap. Complements the keyboard path.
- **Undo last snap** -- ⌘Z after a snap restores the previous window position. Internally: store last-position in memory before each snap operation.
- **Per-layout gap override** -- each named layout can specify its own gap value, overriding the display default. Useful for "tight coding layout" vs. "comfortable reading layout."
- **Snap preview** -- subtle window shadow preview before confirming placement (hover during drag-to-select on the overlay).
- **Multi-window batch snap** -- select multiple app windows and snap them simultaneously to a predefined arrangement. Reduces the number of steps to get into a complex layout.

---

## Phase 3: Intelligence Layer

**Goal:** Layouts that set themselves.

- **Time-based auto-restore** -- restore the correct named layout automatically based on time of day or calendar context (morning standup layout, focus layout, meeting layout).
- **App-open cascade** -- when a specific set of apps is running, trigger a layout automatically. Detected via NSWorkspace notifications on app launch.
- **Focus mode integration** -- when macOS Focus mode activates (work, personal, sleep), switch to the matching display profile and layout.
- **Claude-native session control** -- Claude can query current layout state, enumerate open windows, and rebuild a layout from a natural-language description: "put me in code mode with Xcode on the left two-thirds and Simulator on the right."
- **Layout conflict resolution** -- when an app's per-app rule conflicts with a named layout restore, rule resolution is explicit (layout wins, or rule wins, configurable).

---

## Phase 4: Multi-Display and External Control

**Goal:** Work correctly across every display configuration.

- **Display arrangement simulator** -- preview how a layout will look across different display setups without physically connecting monitors.
- **Per-space layouts** -- macOS Spaces (virtual desktops) each get their own layout slot. Switching spaces switches layouts.
- **Scripting bridge** -- gridforge CLI tool (`gridforge snap left-half`, `gridforge restore --layout code`, `gridforge snapshot save standup`) for Shortcuts, Automator, and shell scripts.
- **Raycast extension** -- expose GridForge layouts in Raycast search (equivalent to the Claude companion but for Raycast users).

---

## Distribution

- **Homebrew tap** -- `brew install --cask gridforge` for one-command install
- **Auto-update** -- Sparkle framework for in-app update checks from the GitHub releases feed
- **Notarization** -- Apple Developer ID notarization so Gatekeeper doesn't flag first launch
- **Setup assistant** -- first-run wizard that requests Accessibility permission and shows the overlay keyboard shortcut; detects display configuration and creates initial profiles

---

*Last updated: 2026-06*
