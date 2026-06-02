# GridForge

A native macOS window placement utility — visual grid overlay, named layouts, per-app snap rules, layout snapshots, and a full companion API so every UI action is reachable from Claude, other AI, or any HTTP client.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## Why this exists

Commercial tools like Divvy, Magnet, and Mosaic cost money and offer no programmatic access. Rectangle is free and open source but has no AI integration, no per-app automation, and no snapshot restore. macOS's built-in window management — Stage Manager aside — requires the mouse and has no memory.

GridForge fills a specific gap: a grid-based window placement tool that is completely headless-ready from day one. Every action available in the UI is callable via the companion API, meaning Claude or any other AI agent can manage your window layout on your behalf, build automations, and restore full workspace states without you touching the mouse.

**Typical use cases:**

- You have a fixed layout for coding (editor left, terminal right, browser top-right) and want it restored in one keystroke — or automatically when those apps open
- You switch between display setups (MacBook alone vs. docked) and want different grids with different per-app defaults per profile
- You want to tell Claude "put me in code mode" and have it arrange your windows without clicking
- You want to save a full workspace state, move some windows around, then restore in one action

---

## Features

### Grid overlay

Press **⌘⇧G** (default, fully rebindable) to show a full-screen translucent grid overlay. Drag to select a region — the overlay calculates the corresponding grid cells, dismisses itself, and snaps the focused window to that frame using `AXUIElementSetAttributeValue`. Press Escape or click outside the grid to dismiss without snapping.

The overlay panel is an `NSPanel` at `.screenSaver` window level with `.canJoinAllSpaces`, so it appears above everything including Stage Manager, full-screen apps, and other panels.

### Configurable grid

Each display has an independent grid configuration stored in SQLite: **columns**, **rows**, and **gap** (pixels of spacing between cells). Default is 6 × 4 with no gap. You can configure up to 20 × 20. Gap pixels are subtracted from cell dimensions before placement, so a 10-pixel gap creates 10px breathing room between windows without affecting the grid math.

Grid configuration is per-display and per-display-profile, so your laptop screen and external monitor each get their own grid.

### Display profiles

When you connect or disconnect a monitor, GridForge detects the new display arrangement and loads the matching profile — a named configuration that maps an arrangement fingerprint (a hash of connected display IDs) to per-display grid configs. Profiles are created automatically on first use and can be renamed in Preferences → Displays.

This means your docked setup (three monitors, dense grids) and your travel setup (laptop only, simpler grid) each have their own grid configs that switch automatically.

### Named layouts

A **named layout** is a saved mapping of app bundle IDs to grid selections — a full window arrangement. Save the current arrangement, give it a name, and optionally bind it to a keyboard shortcut. Restoring a layout calls `AXUIElementSetAttributeValue` on each app's main window to place it back at the saved position and size.

Named layouts are stored in SQLite. They survive across reboots and app restarts.

### Per-app rules

A **per-app rule** maps an app's bundle ID to a grid selection with a trigger: `onLaunch` (fires when the app first opens) or `onFocus` (fires every time the app's window comes to front). When the trigger fires, GridForge silently snaps the app's main window to the configured position.

Example rules:
- Xcode → left ⅔ of screen, on focus
- Simulator → right ⅓ of screen, on focus
- Finder → bottom-right quadrant, on launch

Rules are additive — multiple rules for the same app are allowed but only the first matching rule fires per event.

### Layout snapshots

A **snapshot** captures the current position and size of every visible window across all running apps and saves it to SQLite as a point-in-time restore point. Restoring a snapshot calls `allVisibleWindows()` to enumerate the current window state, then replays the saved frames for each matching bundle ID.

Snapshots are distinct from named layouts: snapshots capture exact pixel frames and support any app, not just apps whose grid position you planned ahead of time.

### Stage Manager compatibility

The overlay panel uses `[.canJoinAllSpaces, .fullScreenAuxiliary]` collection behavior and `.screenSaver` window level, so it renders above the Stage Manager strip and all stage groups. Window snapping via `AXUIElementSetAttributeValue` works on the focused window regardless of Stage Manager state.

**Known limitation:** `allVisibleWindows()` enumerates windows via the AX tree. macOS only exposes windows in the *active* stage group through the AX API — windows parked in other stage groups are not accessible until activated. Layout save and snapshot capture reflect this: only currently visible windows are captured. This is expected OS behavior, not a GridForge bug.

### Companion API (port 14731)

Every UI action is reachable programmatically via a local HTTP server on port 14731 (Phase 5, in progress). The companion API accepts JSON requests, executes the same code paths the UI uses, and returns results — meaning Claude, other AI agents, scripts, and custom tooling can call GridForge exactly like a user would.

The `gridforge-companion.plugin` (Phase 5) wraps the API as a Claude plugin with named skills: "put me in code mode", "save this layout as meeting", "what's my current layout?", "restore yesterday's snapshot".

---

## Install

> **This repo contains source code only — there is no pre-built binary.** You build it yourself in about 30 seconds using the script below. The script handles compilation, app bundle assembly, ad-hoc signing, and installation to `/Applications`.

### Prerequisites

- **macOS 14 Sonoma or later**
- **Xcode Command Line Tools** (free, ~2 GB). If you don't have them:
  ```bash
  xcode-select --install
  ```
  A dialog will appear — click **Install** and wait. Skip this if you already have Xcode installed.

You do **not** need a paid Apple Developer account. You do **not** need the full Xcode app.

### Build & Install

```bash
git clone https://github.com/lswingrover/gridforge ~/Developer/gridforge
cd ~/Developer/gridforge
bash build_app.sh
```

The script compiles the Swift source in release mode, assembles `GridForge.app`, ad-hoc signs it, installs it to `/Applications`, and registers it with LaunchServices. Total time: ~30 seconds on Apple Silicon.

### First launch — Gatekeeper warning

Because GridForge is ad-hoc signed (not notarized by Apple), macOS blocks the first launch with:

> *"GridForge cannot be opened because it is from an unidentified developer."*

**Fix — Option A (GUI):** In Finder, navigate to `/Applications`, right-click `GridForge.app` → **Open** → click **Open** in the confirmation dialog. You only need to do this once.

**Fix — Option B (Terminal):**
```bash
xattr -dr com.apple.quarantine /Applications/GridForge.app
open /Applications/GridForge.app
```

> **Why is it safe?** The ad-hoc signature proves the binary hasn't been tampered with since it was built on your machine. It just lacks Apple's notarization stamp, which is only required for distributing software to other machines.

### First launch — grant Accessibility permission

GridForge moves windows using macOS Accessibility APIs (`AXUIElementSetAttributeValue`). On first launch, macOS prompts for permission:

> *"GridForge would like to control this computer using Accessibility features."*

Click **Open System Settings**, find GridForge in the list, and toggle it on. The overlay will appear but snapping will silently fail until this permission is granted. You can also navigate there manually: **System Settings → Privacy & Security → Accessibility**.

### Updating

```bash
cd ~/Developer/gridforge
git pull
bash build_app.sh
```

The script replaces the existing `/Applications/GridForge.app` automatically.

---

## Usage

GridForge lives entirely in your menu bar — no Dock icon, no app switcher entry (except while Preferences are open).

**Snap a window:**
1. Click the window you want to snap (make it the focused window)
2. Press **⌘⇧G** (default hotkey)
3. Drag across the grid cells you want the window to occupy
4. Release — the window snaps to that region

**Open Preferences:** Click the grid icon in your menu bar → **Preferences…**

**Change the hotkey:** Preferences → Advanced → click the hotkey field and press your new combo.

**Save a layout:** Arrange your windows, then Preferences → Layouts → **Save current as layout** → give it a name.

**Restore a layout:** Preferences → Layouts → click the layout → **Restore**.

**Add a per-app rule:** Preferences → Per-App Rules → **+** → pick an app, choose a grid cell and trigger.

---

## Architecture

```
Sources/
  GridForge/                             Main app target
    GridForgeApp.swift                   @main — MenuBarExtra + Window("Preferences") + Window("About")
    AppState.swift                       @MainActor singleton — owns hotkey, overlay controller,
                                         window manager, display manager, layout + rule state
    AppVersion.swift                     Bundle version string helper
    DisplayManager.swift                 NSScreen enumeration + display ID string generation
    HotkeyManager.swift                  Global NSEvent keyboard shortcut registration/dispatch
    MenuBarView.swift                    Menu bar popover (snap trigger, layout shortcuts, prefs link)
    WindowManager.swift                  AXUIElement window placement engine + allVisibleWindows()
    UpdateChecker.swift                  GitHub releases API poller → update banner in menu
    AboutView.swift                      About window
    Grid/
      GridCanvasView.swift               NSView full-screen overlay — cell hit-testing, drag selection,
                                         keyboard navigation, ESC dismiss
      GridOverlayController.swift        NSPanel lifecycle — show/dismiss, screen routing, ESC global monitor
    Preferences/
      PreferencesView.swift              NavigationSplitView shell — routes to per-tab views
      KeyRecorderView.swift              NSViewRepresentable key-capture widget for hotkey editor

  GridForgeCore/                         Framework target (shared by app + tests)
    GridConfig.swift                     All model types: GridConfig, NamedLayout, LayoutEntry,
                                         PerAppRule, DisplayProfile, SavedShortcut,
                                         SnapshotEntry, LayoutSnapshot
    GridPosition.swift                   GridSelection (column/row span), GridCalculator
                                         (cell → CGRect and CGRect → GridSelection)
    DatabaseManager.swift                SQLite persistence via libsqlite3 — migrations 0001–0003,
                                         all read/write operations for all model types

Tests/
  GridForgeTests/
    DatabaseTests.swift                  22 tests covering all DB operations and migrations
    GridPositionTests.swift              20 tests covering GridCalculator math

build_app.sh                             Build (release) + bundle + ad-hoc sign + install to /Applications
ship_gridforge.py                        Ship script: version bump + git tag + GitHub release
Info.plist                               Bundle metadata (CFBundleIdentifier, LSUIElement, etc.)
```

---

## Design decisions

**Why `NSPanel` at `.screenSaver` level instead of a SwiftUI overlay?**
SwiftUI's overlay and sheet APIs attach to a specific window. GridForge needs to cover the entire screen — above all other apps, above the menu bar, above Stage Manager — without stealing key focus from the app whose window is being moved. `NSPanel` with `.nonactivatingPanel` styleMask lets us show a full-screen overlay that the user can click without the underlying app losing focus. `.screenSaver` window level guarantees it appears above every other window layer including video players, full-screen apps, and Stage Manager groups.

**Why `AXUIElementSetAttributeValue` instead of `CGWindowSetFrameOrigin` or the old `NSWindow` API?**
`CGWindowSetFrameOrigin` only works on windows owned by your own process. GridForge needs to move windows belonging to *other* apps — Safari, Xcode, Terminal, anything. The only public API for that is the macOS Accessibility subsystem via `AXUIElementSetAttributeValue` with `kAXPositionAttribute` and `kAXSizeAttribute`. This requires the user to grant Accessibility permission once, after which GridForge can move any standard window.

**Why `NSEvent.addGlobalMonitorForEvents` for the hotkey instead of Carbon `RegisterEventHotKey`?**
`RegisterEventHotKey` (the old Carbon API) is still functional but requires the app to be running a Carbon event loop, which SwiftUI apps don't. `NSEvent.addGlobalMonitorForEvents` is the modern Cocoa approach and works correctly with SwiftUI's run loop. The tradeoff: global event monitors require Accessibility permission, which GridForge already needs for window manipulation, so there's no additional permission ask.

**Why SQLite via raw libsqlite3 instead of CoreData or GRDB?**
CoreData adds significant boilerplate and generates managed object subclasses that don't compose well with Swift's value-type model. GRDB is excellent but adds a dependency. GridForge's schema is simple — six tables, no joins, no complex queries — and raw libsqlite3 calls with migrations are ~400 lines total. The migration system (numbered functions in `DatabaseManager.swift`) is explicit and readable: each migration is a named function that runs exactly once.

**Why `@MainActor` on `AppState` instead of threading?**
`AppState` holds `@Published` properties that drive SwiftUI views, and SwiftUI requires all `@Published` mutations to happen on the main thread. Marking the whole class `@MainActor` makes off-thread mutation a compile error rather than a runtime crash. Window placement calls (`setFocusedWindowFrame`) also must run on the main thread because `AXUIElement` APIs are not thread-safe. The only background work is the update checker, which uses a detached `Task` and publishes results through a `@MainActor` method.

**Why a `Window` scene for Preferences instead of `Settings`?**
SwiftUI's `Settings` scene creates a window with `maxSize` pinned to the content's `preferredSize`, which makes it non-resizable regardless of what you do to the `styleMask`. A `Window` scene with `.windowResizability(.contentMinSize)` behaves like a normal macOS window — resizable, with a green zoom button, and the size persists across sessions via SwiftUI's built-in frame autosave.

**Why ad-hoc signing instead of Developer ID?**
GridForge is a personal tool. Apple's notarization requirement applies to apps distributed outside the App Store to *other* machines. For local use, ad-hoc signing (`codesign --sign -`) satisfies Gatekeeper's tamper-detection requirement without needing a paid developer account or Apple's notarization servers. If you want to distribute it, swap `--sign -` for `--sign "Developer ID Application: <you>"` and add `xcrun notarytool` to `build_app.sh`.

---

## Configuration

Open **Preferences** from the menu bar icon (or press **⌘,** while Preferences is open).

| Tab | What you can configure |
|-----|------------------------|
| **Grid** | Columns, rows, and gap pixels per display (6 × 4 default) |
| **Shortcuts** | Named layouts with hotkeys; bind any layout to a key combo |
| **Layouts** | Save, restore, rename, and delete named layouts |
| **Displays** | Display profiles — name each monitor arrangement |
| **Per-App Rules** | Map apps to grid positions with launch or focus triggers |
| **Advanced** | Global hotkey, reset to defaults |

---

## Requirements

- macOS 14 Sonoma or later
- Xcode Command Line Tools (for building from source)
- Accessibility permission (prompted on first use; required for window snapping)

---

## Roadmap

| Issue | Feature |
|-------|---------|
| [#9](https://github.com/lswingrover/gridforge/issues/9) | Companion API server — NWListener on port 14731 |
| [#10](https://github.com/lswingrover/gridforge/issues/10) | `gridforge-companion.plugin` for Claude |
| [#11](https://github.com/lswingrover/gridforge/issues/11) | Session analytics — snap history, most-used layouts |

---

## Claude Companion Plugin

*(Phase 5 — in progress)*

Once GH#9–10 ship, install `gridforge-companion.plugin` in Claude → Settings → Capabilities → Customize. Skills planned:

| Trigger | What Claude does |
|---------|-----------------|
| *"Put me in code mode"* | Restores your saved "code" named layout |
| *"Save this as meeting layout"* | Saves current window positions as "meeting" |
| *"What's my current layout?"* | Describes where each visible window is on the grid |
| *"Snap Safari to the left half"* | Calls the snap API for Safari to columns 0–2 |
| *"Restore yesterday's snapshot"* | Restores the most recent saved snapshot |

---

## Related tools

These apps are built by the same author and follow the same install pattern — build from source, no App Store, optional Claude companion plugin:

| App | What it does |
|-----|-------------|
| [MacWatch](https://github.com/lswingrover/MacWatch) | Mac system health — CPU thermals, memory pressure, battery health, process monitoring, composite health score |
| [NetWatch](https://github.com/lswingrover/NetWatch) | Network monitoring — ping latency, DNS health, Wi-Fi metrics, automatic incident bundling and ISP escalation drafts |
| [ClipWatch](https://github.com/lswingrover/ClipWatch) | Clipboard manager — searchable history, sensitive clip detection, Touch ID, hotkey panel |

---

## License

MIT — see [LICENSE](LICENSE).
