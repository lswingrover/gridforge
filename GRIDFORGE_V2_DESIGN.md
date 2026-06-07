# GridForge v2 — Workspace Intelligence Design

**Status:** Planning  
**Date:** 2026-06-06  
**Author:** Claude (Louis Swingrover, sponsor)

---

## Vision

GridForge v1 answers one question: **where should this window go?**

GridForge v2 answers the full question: **what is my workspace, what is happening in it, and how do I control it?**

The upgrade is from a window snapper to a **workspace intelligence layer** — the single place where a human or LLM can observe, understand, and control the entire computing environment. Every feature below serves either observation (know what's happening) or control (act on it), and every UI action has an API equivalent per the existing HEADLESS/UI PARITY convention.

---

## Design Principles

1. **Parity**: every visible action is callable via the companion API. No exceptions.
2. **Locality**: all data is local. No remote calls, no telemetry, no auth tokens to third-party services.
3. **Lightweight by default**: polling is lazy and throttled. GridForge is always resident in the menu bar and must have near-zero idle overhead.
4. **Progressive disclosure**: basic users see a snapper; power users see the full workspace graph; LLMs see the full API.
5. **MacWatch and NetWatch are peers**: GridForge knows windows. MacWatch knows processes. NetWatch knows networks. Together they form a complete observability stack. Coordination is via a shared IPC convention (defined in §Integrations).
6. **Graceful degradation**: features that require private APIs, screen recording permission, or Accessibility have clear fallbacks and permission states.

---

## Feature Domains

### 1. Window Intelligence — The Enriched Window Model

**What it is:** Every visible window gets a rich metadata object beyond its pixel frame.

**Fields added to the window model:**

| Field | Source | Notes |
|---|---|---|
| `windowID` | `CGWindowListCopyWindowInfo` | Stable within a session |
| `title` | `kAXTitleAttribute` | Current window title |
| `documentPath` | `kAXDocumentAttribute` | File path (if app is document-based) |
| `documentURL` | `kAXURLAttribute` | URL (browsers, some apps) |
| `displayName` | User-assigned / heuristic | Persisted in SQLite, survives across sessions |
| `spaceIndex` | CGS private or `CGSGetWindowWorkspace` | Which Mission Control space |
| `displayID` | existing | Which physical display |
| `launchDate` | `NSRunningApplication.launchDate` | When the app was launched |
| `lastFocusedAt` | GF event log | Last time this window was frontmost |
| `totalFocusDuration` | GF event log | Cumulative foreground time |
| `tabCount` | AX children / AppleScript | Browser / terminal tab count |
| `tabTitles` | AX children / AppleScript | Tab title list |
| `isFullScreen` | `kAXFullScreenAttribute` | True if fullscreen |
| `isMinimized` | `kAXMinimizedAttribute` | True if minimized/docked |
| `isHidden` | `NSRunningApplication.isHidden` | True if app hidden (Cmd+H) |
| `windowLevel` | `kCGWindowLayer` | Panel, normal, floating, etc. |
| `sharingState` | `kCGWindowSharingState` | Being shared via screen capture |
| `pid` | `NSRunningApplication.processIdentifier` | For joining with resource data |
| `groupIDs` | SQLite | User-defined group membership |
| `tags` | SQLite | Free-form user tags |
| `thumbnail` | `CGWindowListCreateImage` | Requires Screen Recording permission |

**Why this matters for an LLM:** Claude can ask "what's open?" and get back "Chrome window titled 'Crelate - Louis's Pipeline', last focused 4 minutes ago, 12 tabs open, on Display 1, Space 2." That's actionable context, not just a pixel rectangle.

**Performance contract:** Window metadata is polled at 5-second intervals when the World View panel is closed, 1-second intervals when it's open. Resource fields (CPU, memory) are read from a MacWatch-compatible source at the same cadence. `CGWindowListCreateImage` (thumbnails) is called only on demand or when the grid overlay is shown.

---

### 2. World View Panel — The Workspace Overview

**What it is:** A floating, pinnable panel (not a modal, not the preferences window) showing all windows as a live list. Think: Exposé meets Activity Monitor meets a window manager.

**Layout:**
- **Sidebar left**: grouping axis selector (By App / By Space / By Group / By Zone / By Project / Flat)
- **Main area**: scrollable list of window rows
- **Inspector right** (collapsible): selected window's full metadata, sparklines, tabs, relationships

**Per-window row (compact mode):**
```
[App Icon] [App Name]  [Window Title or custom name]         [badges]  [age]
                                                              🔴⚡📹🔊  14m
```

Badges:
- 🔴 CPU > threshold (from MacWatch or direct proc_pidinfo)
- 💾 Memory > threshold
- ⚡ High power impact
- 📹 Camera in use
- 🎙 Microphone in use
- 🔊 Producing audio
- 🌐 Active network I/O
- 🔴 NetWatch incident affecting this app
- 🔗 Screen sharing in progress (kCGWindowSharingState)
- ⏸ Paused (SIGSTOP'd by user)

**Per-window row (detailed mode):**
Expanded row shows:
- Document path or URL (truncated, click to reveal)
- Tab count badge ("12 tabs")
- Space indicator ("Space 2")
- Resource sparklines (CPU 1-min sparkline, memory bar)
- Group tags as colored pills

**Interaction:**
- Click → focus that window
- Right-click → full context menu (see §Controls)
- Drag row → add to group / reorder group
- Double-click title → inline rename (assigns display name)
- Cmd+click → multi-select for bulk actions
- ⌘K → opens command palette prefilled with window search

**Views:**
- **List view** (default)
- **Card view**: larger cards with live thumbnails (requires Screen Recording)
- **Grid map view**: mirrors the physical display grid, shows windows as overlaid labels on the grid canvas

**Pinning:** The panel can be docked to the left or right edge of any display, or float freely. Its position and width are persisted. When docked, it nudges the usable work area (via NSScreen margin, if supported in future macOS) or just overlaps.

---

### 3. Window Inspector

**What it is:** A detail pane for a single selected window. Accessible via the World View panel's right sidebar or by right-clicking any window in the grid overlay.

**Tabs:**

**Overview tab:**
- App icon, name, bundle ID, version
- Window title, document path/URL
- Grid position (human-readable: "Left ⅔ of Display 1, rows 1–3")
- Space + display
- Running for: "3h 42m" (since app launch)
- Last focused: "4m ago"
- Total focus today: "1h 12m"
- Custom name (editable inline)
- Tags (editable inline with autocomplete)
- Group membership (clickable pills)

**Resources tab:**
- CPU usage: sparkline (last 10 min) + current %
- Memory: used / RSIZE / VSIZE, trend arrow
- Power impact: low / medium / high + wattage if MacWatch provides it
- Disk I/O: reads/writes per second
- Network I/O: sent/received per second
- Open file descriptors (count)
- Data source indicator: "MacWatch" or "proc_pidinfo"

**Tabs/Content tab** (for browsers, terminals, editors):
- List of all tabs with titles
- For browsers: favicons, URLs, active indicator
- For terminals: shell session info (cwd if accessible via AX)
- For editors: open file list (via AX document list if available)

**History tab:**
- Timeline of focus events (today)
- Heatmap: hour-by-hour focus frequency (7-day)
- Snap history: layout changes applied to this window
- "Was in layout: Code Mode (10:42am)"

**Relations tab:**
- "Related windows" — heuristic matches:
  - Same file/directory open in multiple apps
  - Same domain as browser URL
  - App launched by this app
  - Temporal co-occurrence (usually focused together)
- Shared group members
- Suggested grouping

**Actions panel (always visible):**
Quick-action buttons: Focus · Hide · Minimize · Move to Space · Kill · Pin · Screenshot · Add to Group

---

### 4. Controls — Full Window Control Surface

**Per-window actions (UI + API):**

| Action | Mechanism | Notes |
|---|---|---|
| Focus / bring to front | `NSRunningApplication.activate()` + AX raise | |
| Close | `kAXCloseButtonAttribute` press via AX | Respects app's close behavior |
| Force close | `NSRunningApplication.terminate()` | Sends SIGTERM |
| Kill | `NSRunningApplication.forceTerminate()` | Sends SIGKILL |
| Hide | `NSRunningApplication.hide()` | Equivalent to Cmd+H |
| Unhide | `NSRunningApplication.unhide()` | |
| Minimize | `kAXMinimizedAttribute` = true | |
| Unminimize | `kAXMinimizedAttribute` = false | |
| Fullscreen toggle | `kAXFullScreenAttribute` toggle | |
| Move (grid) | existing AX frame set | |
| Move (pixel-precise) | existing AX frame set | |
| Move to display | frame set on target display coordinate | |
| Move to space | CGS private: `CGSMoveWindowToSpace` | Fallback: simulate drag to Mission Control |
| Pin / always on top | `NSWindow.level` via AX — not fully public; best approach: create a transparent overlay window that holds on top and delegates clicks through | Alternative: companion app trick |
| Pause | `kill(pid, SIGSTOP)` | Process frozen; use sparingly |
| Resume | `kill(pid, SIGCONT)` | Resume a paused process |
| Screenshot | `CGWindowListCreateImage` | Saves to clipboard or file |
| Rename (display name) | SQLite `window_names` table, matched by bundle ID + title pattern | |
| Tag | SQLite `window_tags` table | |
| Add to group | SQLite `window_groups` membership | |
| Relaunch | terminate + workspace open with same path | App-specific; best-effort |

**Pause/Resume note:** SIGSTOP is the only portable "freeze" mechanism. Most apps survive it fine for short periods. Apps with watchdog timers (e.g. Electron apps with IPC watchdogs) may crash after a few seconds. UI clearly marks paused windows and warns on long pauses.

**Per-group actions:**
- Bring all to front (in saved order)
- Hide all
- Minimize all
- Tile in current grid (distribute evenly across cells)
- Save as named layout
- Close all (with confirmation if > N windows)
- Screenshot all (montage export)

**Workspace-wide actions:**
- Minimize all except focused window ("Focus Mode")
- Hide all except focused
- Bring all minimized to front
- Distribute all visible windows evenly across grid
- Save current state as snapshot (existing, surfaced more prominently)
- Clear all custom names (with confirmation)

---

### 5. Window Groups

**What they are:** User-defined sets of windows that persist across sessions and can be acted on as a unit. Groups are orthogonal to layouts — a layout says "where," a group says "who belongs together."

**Group properties:**
- Name
- Color label (for visual identification in World View)
- Icon (from a curated set, or the member app's icon)
- Optional hotkey to restore/bring-to-front
- Optional layout association ("when this group is restored, apply layout X")
- Notes (free text)

**Group membership:**
- Manual: drag windows into a group in World View, or right-click → Add to Group
- Pattern-based: "automatically include any Chrome window whose URL contains `crelate.com`"
- Path-based: "automatically include any window whose document path starts with `~/Developer/gridforge`"
- Temporal: "include windows I typically open together" (heuristic from history)

**Auto-group suggestions:**
GridForge monitors window open/close co-occurrence and suggests groups: "You often have Xcode, Terminal, and Simulator open at the same time. Save as 'Development' group?"

**Group save/restore:**
Saving a group records the current position of all member windows as a layout. Restoring focuses and positions all member windows. If a member window isn't open, GridForge optionally launches the app.

---

### 6. Named Windows

**The problem:** Windows are ephemeral — they close, reopen, and the title changes. You need a stable human name for "the Crelate window" even though its title is "Louis Swingrover - Crelate" and changes based on what's loaded.

**Solution:** A `window_names` SQLite table maps a (bundle ID, title pattern) pair to a user-assigned display name. When GridForge sees a window that matches a saved pattern, it surfaces the display name everywhere in the UI and API.

**Naming flow:**
1. Double-click any window title in World View
2. Type the display name (e.g. "Crelate")
3. Optionally choose whether to match on full title or title prefix
4. Save → persisted

**API access:**
`GET /windows` returns both `title` (raw OS title) and `displayName` (user-assigned, or title if none assigned). `POST /windows/:id/rename` updates the display name.

**LLM value:** Claude can refer to windows by their human names rather than raw OS titles: "snap Crelate to the right half" works via `GET /windows?name=Crelate` → `POST /windows/:id/move`.

---

### 7. Timeline & Activity History

**Event log:** GridForge records window lifecycle events to SQLite:

| Event | Trigger |
|---|---|
| `window_opened` | NSWorkspace applicationDidLaunch + AX window created |
| `window_closed` | AX window destroyed notification |
| `window_focused` | `NSWorkspace.didActivateApplicationNotification` + AX focus |
| `window_blurred` | Same, inverse |
| `window_moved` | AX position change notification |
| `window_resized` | AX size change notification |
| `layout_applied` | GF internal |
| `snapshot_saved` | GF internal |
| `snapshot_restored` | GF internal |
| `group_restored` | GF internal |
| `app_paused` | SIGSTOP sent |
| `app_resumed` | SIGCONT sent |

**Retention:** 30 days default, configurable. Events are timestamped and indexed by bundle ID and window ID.

**Analytics derived from events:**
- Most-focused app (today / week / month)
- Most-used layout (by apply count)
- Most-used grid positions (heatmap)
- Average session length per app
- Longest continuously running window
- Windows that are open but never focused ("zombie windows")
- Peak workspace complexity (max concurrent window count by hour)

**Timeline UI:**
- Horizontal timeline in World View Inspector (today's focus events)
- 7-day heatmap per window (focus intensity by hour)
- Session summary at end of day: "Today: 6h focus time across 12 apps, Code Mode layout applied 4×"

**API:**
```
GET /timeline?since=2026-06-05T09:00:00Z&until=2026-06-06T17:00:00Z
GET /timeline/sessions          — day boundaries inferred from long idle gaps
GET /analytics                  — aggregated stats
GET /analytics/layouts          — layout usage frequency
GET /analytics/positions        — grid position heat map
GET /analytics/apps             — per-app focus stats
```

---

### 8. Automation Engine v2

**Current system:** Simple per-app rules with `onLaunch` / `onFocus` triggers. One rule fires per event.

**v2 expands to:**

**Trigger types:**

| Trigger | Example |
|---|---|
| App launched | "When Zoom launches" |
| App quit | "When Zoom quits, restore previous layout" |
| Window opened | "When any Chrome window opens" |
| Window focused | existing |
| Display profile changed | "When docked: apply Dense Grid layout" |
| Time of day / day of week | "At 9am weekdays: restore Morning layout" |
| Space switched | "When switching to Space 3: apply Focus Mode" |
| Group restored | "When Work group restored: apply Work layout" |
| MacWatch event | "When CPU thermal > 85°C: close non-essential windows" |
| NetWatch event | "When internet connectivity lost: apply Offline layout" |
| Manual trigger | Hotkey, menu item, API call |
| Idle | "After 2h of no focused window: minimize all" |

**Condition modifiers:**
- Time window: "only between 9am–6pm"
- Display profile: "only on laptop display profile"
- App state: "only if Zoom is also running"
- Battery state: "only on AC power"
- Override: "except when in Focus Mode"

**Action types:**
- Apply named layout
- Restore snapshot
- Move window to grid position
- Move window to display
- Hide / show window
- Launch app
- Kill app
- Focus window
- Create notification
- Run shell command (power user, with confirmation on first setup)
- Trigger GridForge companion API call

**Rule chaining:** Rules can trigger other rules (with loop detection). "On dock: restore Full Grid layout AND apply per-display zoom rules."

**Rule editor UI:** A visual rule builder in Preferences → Automation. Each rule shows: Trigger → [when conditions] → Actions. Preview mode: "If this rule fired now, it would: [list of actions]."

---

### 9. Command Palette

**What it is:** A Spotlight-style quick-action panel, triggered by ⌘K from anywhere (configurable). The single fastest interaction surface for power users and for AI.

**Supports:**
- Window actions: "focus Crelate", "close Zoom", "snap Chrome to left half", "kill Slack"
- Layout actions: "code mode", "apply meeting layout", "save as standup"
- Snapshot actions: "restore yesterday's snapshot"
- Group actions: "restore work group", "hide development group"
- System: "show world view", "preferences", "analytics"
- Free-form: any action expressible as natural language → matched to best action

**UI:** Floating panel centered on screen (or active display), fuzzy-matched, keyboard-only. ↑↓ to navigate, Enter to execute, Esc to dismiss. Groups results by category (Windows, Layouts, Snapshots, Groups, Actions). Shows keyboard shortcut if one is bound.

**API integration:** `POST /command` accepts natural language action strings, finds the best match, and executes it. Returns the action taken. This gives Claude a high-level action channel: instead of knowing exact API endpoints, Claude can POST "snap the browser to the right third" and GridForge resolves it.

---

### 10. Grid Overlay Enhancements

**Current:** Translucent grid, drag to select, snap on release.

**v2 additions:**

**Window label overlay:** In each occupied grid cell, show the name (app icon + display name) of the window currently occupying that region. So before you snap, you see "Chrome" in the left half and "Xcode" in the right third. Helps you decide where to put the new window.

**Live thumbnail mode:** If Screen Recording permission is granted, render a live thumbnail of each window inside its grid cell. The overlay becomes a miniaturized version of your workspace — you drag to select knowing exactly what's where.

**Group color coding:** Cells containing windows from named groups are tinted with the group's color, giving instant visual context about which "project zone" each screen region belongs to.

**Suggested snap targets:** Based on history, highlight cells with a subtle glow indicating "you often snap this app here." The strongest suggestion appears as the default selection when the overlay opens.

**Multi-window mode:** Hold ⌥ to select multiple cells for multiple windows in sequence (lay out a set of windows without dismissing the overlay between snaps).

**Zone labels:** Named grid zones (user-defined, e.g. "Work Zone" = columns 0–3, rows 0–3; "Tools Zone" = columns 4–5) appear as translucent labels behind the grid. Helps with cognitive mapping.

---

### 11. Display & Space Intelligence

**Space awareness:**
- Show which Space each window is on (integer index or user-named space)
- Space overview in World View: compact map of all spaces with window count per space
- Move window to space via API and UI (CGS private APIs: `CGSMoveWindowToSpace`, `CGSGetActiveSpace`, `CGSSpaces`)
- Create space-aware layouts and snapshots (record and restore which space each window belongs to)
- "Bring all from Space 3" — move all windows from a space to the current space

**Space naming:** GridForge reads user-assigned space names from CGS and surfaces them (Spaces 1–N, or "Work / Personal / Focus" if the user named them in Mission Control).

**Multi-display intelligence:**
- Per-display window count and occupancy at a glance
- "Balance across displays" — distribute windows evenly across all connected displays
- Display-aware group layouts: a group's layout can specify "primary display" and "secondary display" positions
- When a display disconnects, GridForge optionally auto-consolidates its windows to the remaining display (per a rule)

---

### 12. External Access & Control Visibility

**The question:** What other programs have control over, or access to, my windows?

**What GridForge can surface:**
- **Screen capture sharing state**: `kCGWindowSharingState` from `CGWindowListCopyWindowInfo` — whether a window is being shared/captured by another app (e.g. Zoom, Loom, QuickTime screen recording)
- **Accessibility clients**: list of processes that have Accessibility access (via TCC database reading — best-effort, may require special entitlements)
- **Camera/mic indicators**: via `AVCaptureDevice.isBeingUsedByAnotherApplication` and the system privacy indicators
- **Screen recording permission holders**: apps that have been granted `kTCCServiceScreenCapture`

**UI surface:** In the World View, a window badge indicates if it's being screen-shared. In the Inspector's Overview tab, an "External Access" section lists what has access.

**Note on TCC:** Direct reading of the TCC database requires SIP-bypass in some macOS versions. Fallback: use `proc_pidinfo` to detect processes with `CoreGraphics` connections, which is a reasonable proxy for screen-capture-capable apps.

---

## Integrations

### MacWatch Integration

**Shared data protocol:** MacWatch and GridForge communicate via a shared SQLite database at `~/Library/Application Support/GridForge/macwatch_bridge.sqlite` (or a configurable path). MacWatch writes process metrics; GridForge reads them, joining on PID.

**Alternatively:** If MacWatch exposes its existing SQLite DB path, GridForge reads it directly (read-only). MacWatch already tracks `cpu_percent`, `memory_mb`, `thermal_state`, `energy_impact` per process.

**What GridForge gets from MacWatch:**
- CPU%, memory MB, thermal state, power impact per PID → shown as badges and sparklines on windows
- Process alerts (high CPU, memory pressure) → notification badges in GridForge World View and grid overlay
- MacWatch forensic sweep results → surfaceable in Window Inspector for any suspicious app

**What GridForge gives MacWatch:**
- Window context: "PID 1234 has the window titled 'Crelate - Louis's Pipeline' on Display 1, Space 2." MacWatch can enrich its process entries with window context for richer diagnostics.
- User-defined process names: "PID 1234 is the app I've named 'Crelate'." Humanizes MacWatch alerts.

**Coordination scenarios:**
- High-CPU badge on a window in GridForge → user right-clicks → "Diagnose in MacWatch" → opens MacWatch inspector for that process
- MacWatch alert: "Chrome > 2GB RAM" → GridForge shows a notification badge on all Chrome windows with an option to "close unused tabs" or "kill process"
- GridForge "Kill" action → also triggers MacWatch to log the kill event in its security log

**Event bus (NSDistributedNotificationCenter):**  
```
com.gridforge.event.windowFocused       → payload: {bundleID, pid, windowTitle}
com.gridforge.event.resourceAlert       → payload: {pid, metric, value, threshold}
com.macwatch.event.processAlert         → payload: {pid, alertType, value}
com.macwatch.event.thermalEvent         → payload: {state, temperature}
```

GridForge subscribes to `com.macwatch.*` for badge updates. MacWatch subscribes to `com.gridforge.*` for window context enrichment.

---

### NetWatch Integration

**Shared data:** NetWatch writes incident bundles to `~/network_tests/incidents/`. GridForge polls this directory for recent incidents (last 30 min) and surfaces them.

**What GridForge gets from NetWatch:**
- Active incidents (connectivity loss, high latency, DNS failure)
- Per-app network I/O — if NetWatch exposes this via Firewalla or packet-capture data
- Incident severity and affected services

**What GridForge does with NetWatch data:**
- Connectivity incident → NetWatch badge on all browser and network-dependent windows
- Automation trigger: "When NetWatch reports connectivity loss: apply Offline Layout" (layout that minimizes cloud-dependent apps, maximizes local tools)
- Inspector "Network" tab shows per-window network I/O sparklines

**Event bus:**
```
com.netwatch.event.incidentStarted     → payload: {severity, affectedServices[]}
com.netwatch.event.incidentResolved    → payload: {incidentId}
com.netwatch.event.connectivityLoss    → payload: {duration}
```

GridForge automation rules can trigger on these events.

---

## API Design — Full Endpoint Reference

All endpoints on `http://localhost:14731`. JSON request/response. Auth token optional (configurable in Preferences → Advanced).

### Core State
```
GET  /get-state                 (existing) version, hotkey, layouts, shortcuts, snapshots
GET  /status                   health check + version + uptime
```

### Windows
```
GET  /windows                  all windows with enriched metadata
                               query: ?grouped=true, ?space=N, ?display=X, ?group=G, ?tag=T
GET  /windows/:id              single window detail
GET  /windows/:id/thumbnail    PNG image (requires Screen Recording permission)
GET  /windows/:id/context      LLM-ready context object: title, doc, tabs, relations, resources
GET  /windows/:id/history      focus/activity event history for this window
GET  /windows/:id/relations    related windows (shared path, URL, temporal co-occurrence)

POST /windows/:id/focus        bring to front
POST /windows/:id/close        AX close button
POST /windows/:id/kill         SIGKILL via forceTerminate
POST /windows/:id/hide         NSRunningApplication.hide()
POST /windows/:id/unhide
POST /windows/:id/minimize
POST /windows/:id/unminimize
POST /windows/:id/fullscreen   toggle fullscreen
POST /windows/:id/move         body: {col, row, colSpan, rowSpan} or {frame: {x,y,w,h}}
POST /windows/:id/move-to-display  body: {displayID}
POST /windows/:id/move-to-space    body: {spaceIndex}
POST /windows/:id/pin          always-on-top
POST /windows/:id/unpin
POST /windows/:id/pause        SIGSTOP
POST /windows/:id/resume       SIGCONT
POST /windows/:id/screenshot   body: {dest: "clipboard"|"file", path?}
POST /windows/:id/rename       body: {name, matchMode: "exact"|"prefix"|"contains"}
POST /windows/:id/tag          body: {tags: [...]}
POST /windows/:id/group        body: {groupID}
POST /windows/:id/ungroup      body: {groupID?}
```

### Groups
```
GET  /groups                   all groups with member lists
POST /groups                   create group; body: {name, color?, hotkey?, layoutID?}
GET  /groups/:id               group detail + current members
PUT  /groups/:id               update group properties
DELETE /groups/:id
POST /groups/:id/focus         bring all windows to front
POST /groups/:id/hide          hide all
POST /groups/:id/minimize      minimize all
POST /groups/:id/tile          distribute evenly across current grid
POST /groups/:id/close         close all (with force option)
POST /groups/:id/save-layout   save current positions as layout
POST /groups/:id/screenshot    capture montage
GET  /groups/:id/members       live member list (windows currently matching group)
POST /groups/suggest           analyze history, return suggested groups
```

### Workspace
```
GET  /workspace                full workspace: all windows, spaces, displays, groups
GET  /workspace/context        LLM-optimized context summary (human-readable + structured)
GET  /workspace/snapshot       current pixel-precise state (same as existing snapshot save but without persisting)
```

### Spaces
```
GET  /spaces                   all Mission Control spaces with window membership
GET  /spaces/active            current active space
POST /spaces/:index/focus      switch to space
POST /spaces/:index/windows    list windows in space
```

### Displays
```
GET  /displays                 connected displays with grid config and window list
GET  /displays/:id/windows     windows on this display
```

### Layouts (extended from existing)
```
GET  /list-layouts             (existing)
POST /apply-layout             (existing)
POST /save-layout              (existing)
GET  /layouts/:id/preview      thumbnail PNG of layout canvas
POST /layouts/:id/rename
DELETE /layouts/:id
```

### Snapshots (extended)
```
GET  /list-snapshots           (existing)
POST /apply-snapshot           (existing)
GET  /snapshots/:id/preview    thumbnail PNG
POST /snapshots/:id/rename
DELETE /snapshots/:id
```

### Resources / Monitoring
```
GET  /resources                all windows with current CPU/mem/power/net (joined from MacWatch or proc_pidinfo)
GET  /resources/history        time-series (last N minutes); query: ?window=id, ?minutes=10
GET  /resources/top            highest-consuming windows; query: ?by=cpu|memory|power|network
```

### Timeline & Analytics
```
GET  /timeline                 window lifecycle events; query: ?since=ISO8601&until=ISO8601
GET  /timeline/sessions        inferred session boundaries (long idle gaps)
GET  /analytics                aggregated stats (focus time, layout usage, app usage)
GET  /analytics/positions      grid position heatmap (cell → usage count)
GET  /analytics/apps           per-app focus duration, last seen, session count
GET  /analytics/layouts        layout apply frequency + last used
```

### Automation Rules
```
GET  /rules                    all automation rules
POST /rules                    create rule; body: {trigger, conditions?, actions[]}
GET  /rules/:id
PUT  /rules/:id
DELETE /rules/:id
POST /rules/:id/test           dry-run: evaluate rule in current environment
POST /rules/:id/fire           manual trigger: execute rule now
GET  /rules/pending            rules that would fire in next 24h (time-based)
```

### Commands (natural language)
```
POST /command                  body: {text: "snap Chrome to the right half"} → resolves and executes
GET  /command/suggest          body: {text: partial string} → returns matching commands
```

### Integrations
```
GET  /integrations/macwatch    MacWatch sensor data for running processes (if bridge active)
GET  /integrations/netwatch    NetWatch current incident state (if bridge active)
POST /integrations/macwatch/subscribe  subscribe to MacWatch push events (webhook to localhost)
POST /integrations/netwatch/subscribe
```

### Streaming (Server-Sent Events)
```
GET  /stream/events            SSE: window lifecycle events (open/close/focus/resize/move)
GET  /stream/resources         SSE: resource metric snapshots at 5s intervals
GET  /stream/alerts            SSE: alert events (high resource usage, NetWatch incidents)
```

### Snap (extended)
```
POST /set-window               (existing) focused window to grid cell
POST /set-window/:id           specific window by ID to grid cell
```

---

## Plugin Skills — gridforge-companion.plugin

Expanded from the current planned 5 skills to a full set:

### Observation skills

| Skill trigger | What Claude does |
|---|---|
| "what's open" / "what do I have open" | `GET /workspace/context` → humanized summary of all open windows |
| "gridforge status" | `GET /status` + `GET /workspace` → health + window count |
| "what's on screen" | `GET /windows` with thumbnail URLs → visual + text summary |
| "what's using the most CPU/memory" | `GET /resources/top` → surface top offenders |
| "what windows are in [group]" | `GET /groups/:id/members` |
| "show me the history of [window]" | `GET /windows/:id/history` |
| "what did I have open this morning" | `GET /timeline?since=...` → reconstruct session |
| "are any windows paused" | `GET /windows?state=paused` |
| "what's sharing my screen" | `GET /windows` → filter by sharingState |

### Control skills

| Skill trigger | What Claude does |
|---|---|
| "put me in [layout name]" | `POST /apply-layout` |
| "save this as [name]" | `POST /save-layout` |
| "snap [app] to [position]" | `GET /windows?app=X` → `POST /windows/:id/move` |
| "close [app/window]" | `GET /windows?name=X` → `POST /windows/:id/close` |
| "kill [app]" | `GET /windows?name=X` → `POST /windows/:id/kill` |
| "hide everything except [app]" | bulk hide via `/windows/:id/hide` |
| "focus mode" | hide all non-focused windows |
| "move [app] to display 2" | `GET /windows?app=X` → `POST /windows/:id/move-to-display` |
| "pause [app]" | `POST /windows/:id/pause` (with user confirmation) |
| "restore [group]" | `POST /groups/:id/focus` |
| "tile my windows" | `POST /workspace/tile` |

### Intelligence skills

| Skill trigger | What Claude does |
|---|---|
| "suggest a layout for what I'm doing" | `GET /workspace/context` → analyze → recommend layout |
| "what should I clean up" | `GET /analytics` → surface zombie windows, old snapshots |
| "what have I been working on today" | `GET /analytics/apps` + `/timeline` → generate summary |
| "set up a rule for [app]" | natural language → `POST /rules` with constructed rule |
| "what's slowing my computer down" | `GET /resources/top` + MacWatch bridge → diagnosis |

### Automation skills

| Skill trigger | What Claude does |
|---|---|
| "every morning at 9am apply [layout]" | `POST /rules` with time trigger |
| "when Zoom opens, move everything to the left display" | `POST /rules` with app launch trigger |
| "remind me if Chrome exceeds 2GB" | `POST /rules` with resource threshold trigger |

---

## UI/UX Summary

### Interaction hierarchy (fastest to slowest)
1. **Hotkey** → grid overlay → drag → snap (existing, kept)
2. **Command Palette** (⌘K) → type → execute any action in < 3 keystrokes
3. **World View Panel** → click → right-click → menu → action
4. **Menu bar popover** (existing, enhanced with quick window list + badge count)
5. **Preferences** (existing, extended with Automation, Groups, Analytics tabs)

### Visual design principles
- Badges are small and neutral until there's something worth knowing — no visual noise for healthy state
- Color is used for groups (user-chosen) and alert severity (green/yellow/red from MacWatch) only
- Thumbnails are opt-in (require Screen Recording permission and are off by default — battery and privacy)
- Dark mode first; all colors use semantic system colors
- The World View panel respects reduced transparency settings

### Accessibility
- All World View interactions are keyboard-navigable
- VoiceOver labels on all badges
- High-contrast mode for badge colors

---

## Implementation Phases

### Phase 1 — Enriched Window Model & Core API Expansion (Foundation)
**Scope:**
- Extend `WindowManager.allVisibleWindows()` to return the full enriched window model (title, doc path, URL, space, launch date, last focus, PID)
- Add `WindowIntelligenceManager` for resource polling via `proc_pidinfo` + optional MacWatch bridge
- SQLite schema v4: `window_events`, `window_names`, `window_tags`, `window_groups`, `window_group_membership`
- New API: `/windows`, `/windows/:id`, `/windows/:id/context`, `/resources`, `/timeline`
- Extend `/get-state` to include window intelligence summary

**Deliverable:** The API tells you everything about every window.

### Phase 2 — World View Panel
**Scope:**
- Floating SwiftUI panel (`NSPanel`, non-activating, `.floating` level)
- List view with grouping, badges, resource indicators
- Window Inspector sidebar (Overview + Resources tabs)
- Inline rename
- Right-click context menu (all per-window actions)
- Basic multi-select

**Deliverable:** Users can see and interact with all windows from one panel.

### Phase 3 — Controls & Groups
**Scope:**
- Full control surface: hide, kill, pause/resume, pin, move-to-space, move-to-display
- Window groups: create, edit, save, restore
- Group API endpoints
- `/command` endpoint (natural language action router)

**Deliverable:** Full control surface, including group management.

### Phase 4 — Grid Overlay Enhancements
**Scope:**
- Window label overlay (app name in occupied cells)
- Optional live thumbnail mode (behind Screen Recording permission gate)
- Group color coding in overlay
- Suggested snap target highlighting

**Deliverable:** The overlay shows your workspace, not just a grid.

### Phase 5 — Command Palette
**Scope:**
- ⌘K global hotkey → floating palette
- Fuzzy window/layout/group/action search
- Keyboard-only navigation and execution

**Deliverable:** Fastest possible human interaction surface.

### Phase 6 — Timeline & Analytics
**Scope:**
- Window event logging to SQLite
- Activity history in Inspector
- Analytics aggregation
- `/timeline` and `/analytics` API endpoints
- Analytics tab in Preferences

**Deliverable:** Historical context for every window and session.

### Phase 7 — Automation Engine v2
**Scope:**
- Extended trigger types (time, display change, MacWatch events, NetWatch events)
- Condition modifiers
- Chain rules
- Rule editor UI in Preferences → Automation
- `/rules` API

**Deliverable:** Hands-free workspace orchestration.

### Phase 8 — MacWatch & NetWatch Integration
**Scope:**
- MacWatch bridge: shared SQLite reader + NSDistributedNotificationCenter subscriber
- NetWatch bridge: incident directory poller
- Resource badges sourced from MacWatch
- NetWatch incident badges on affected windows
- Automation triggers for MacWatch/NetWatch events
- `/integrations/*` API

**Deliverable:** The three tools form a unified observability + control stack.

### Phase 9 — Streaming API & Plugin Expansion
**Scope:**
- SSE streaming endpoints (`/stream/events`, `/stream/resources`, `/stream/alerts`)
- Full plugin skill set (all skills listed above)
- LLM-optimized `/workspace/context` endpoint tuning

**Deliverable:** Claude has live awareness of the workspace, not just point-in-time snapshots.

### Phase 10 — Space & Display Intelligence (Advanced)
**Scope:**
- Full space enumeration and window-to-space mapping (CGS private APIs, with fallback)
- Move-to-space via API and UI
- Space-aware layouts and snapshots
- Multi-display balance and consolidation

**Deliverable:** Complete workspace control including Mission Control spaces.

---

## Technical Notes & Constraints

### Private APIs
**CGS (CoreGraphics Services):** Space management (`CGSMoveWindowToSpace`, `CGSGetActiveSpace`, `CGSSpaces`) is private but widely used by Moom, BetterTouchTool, Magnet, and Swish without App Store issues. Risk: may break on major macOS version. Mitigation: wrap in a `SpaceManager` class with a public fallback path that degrades gracefully when the symbols are unavailable.

**TCC (Transparency, Consent, Control):** Reading `/Library/Application Support/com.apple.TCC/TCC.db` for permission auditing requires SIP changes or special entitlements on modern macOS. Fallback: use process-level heuristics (processes connected to CoreGraphics, processes playing audio via CoreAudio).

### Permission Requirements

| Feature | Permission | Fallback |
|---|---|---|
| Window snapping | Accessibility | — (core feature, no fallback) |
| Window metadata (title, doc) | Accessibility | — |
| Space management | Accessibility + CGS private | Move-to-space unavailable |
| Window thumbnails | Screen Recording | Thumbnails disabled |
| Process resource data | None (proc_pidinfo is public) | — |
| Audio status | None (CoreAudio session is public) | — |
| Camera/mic indicators | None (AVCaptureDevice.isBeingUsedByAnotherApplication) | — |
| Screen sharing state | Accessibility + CGWindowListCopyWindowInfo | — |
| SIGSTOP/SIGCONT | None (signals to processes you own) | Non-owned processes: error |

### Battery & CPU overhead
- Resource polling: lazy, 5s default when idle, 1s when World View open
- Event log writes: batched, every 10s flush
- SSE stream: only active when a client is connected
- Thumbnails: never polled; only on demand (API call or overlay show)
- Target overhead: < 0.5% CPU, < 50MB RAM when idle

### Stability
- All private API calls wrapped in `dlsym` lookups + availability checks
- AX calls are fallible — all wrapped in `try?` or `Result`
- SIGSTOP/SIGCONT require confirmation in UI; API exposes `force: true` flag
- Window ID stability: CGWindowID is session-stable but not persisted; use (bundleID, title-pattern) for cross-session references

### Security model
- Companion API remains localhost-only
- Optional bearer token auth (configurable in Preferences → Advanced → "Require API token")
- SIGKILL actions require `force: true` in API body
- SIGSTOP requires same
- `/command` natural language parser sanitizes inputs before dispatching

---

## Open Questions

1. **World View docking**: should the panel dock to the screen edge and shrink the available work area, or simply float/overlap? Stage Manager complicates the former.
2. **Group persistence across sessions**: when an app is relaunched, its window IDs change. How aggressively do we try to re-member windows to their groups? Options: exact title match, title prefix match, "any window from this bundle ID."
3. **SIGSTOP UX**: how long should a pause last before GridForge warns? Some Electron apps watchdog-quit within 5 seconds.
4. **Automation rule conflicts**: if two rules try to move the same window to different positions on the same trigger, last-write-wins or first-wins? Need a priority field.
5. **Space enumeration on macOS 15+**: Apple has been tightening CGS access. What's the most current approach used by BetterTouchTool?
6. **MacWatch IPC protocol**: shared SQLite vs. NSDistributedNotificationCenter vs. local HTTP. The MacWatch companion server (if it has one) might already expose the right data. Align before implementing.
7. **Tab enumeration for browsers**: Safari tabs via AppleScript are reliable. Chrome via ScriptingBridge works but requires Chrome to have Automation permission granted. Firefox has no AppleScript bridge. Design for Safari + Chrome as first-class, others as best-effort.
