#!/usr/bin/env python3
"""File GridForge v2 GitHub issues. Run via: python3 scripts/file_v2_issues.py"""
import subprocess, sys, json

REPO = "lswingrover/gridforge"
GH = "/opt/homebrew/bin/gh"

issues = [
    {
        "title": "feat(v2/p1): Enriched Window Model & Core API Expansion",
        "body": """## Phase 1 — Foundation

Extend every window entry beyond its pixel frame to a full metadata object. This is the substrate every other v2 feature depends on.

### New window model fields
- `title` (kAXTitleAttribute), `documentPath` (kAXDocumentAttribute), `documentURL` (kAXURLAttribute)
- `displayName` — user-assigned label, persisted in SQLite via (bundleID + titlePattern) key
- `spaceIndex` — Mission Control space (CGS private API with graceful fallback)
- `launchDate` / `lastFocusedAt` / `totalFocusDuration` — NSRunningApplication + GF event log
- `tabCount` / `tabTitles` — AX children / AppleScript for browsers and terminals
- `sharingState` — kCGWindowSharingState (is this window being screen-captured?)
- `pid`, `groupIDs`, `tags`, `thumbnail` (CGWindowListCreateImage, Screen Recording required)
- Resource fields: CPU%, memory, power impact, disk I/O, network I/O (proc_pidinfo + optional MacWatch bridge)

### SQLite schema v4 additions
- `window_events` — lifecycle event log (focus, open, close, move, resize, snap, tag, group)
- `window_names` — (bundleID, titlePattern, matchMode) → displayName
- `window_tags` — free-form tags per window identity
- `window_groups` + `window_group_membership`

### New API endpoints
- `GET /windows` — full enriched list (?grouped, ?space, ?display, ?group, ?tag)
- `GET /windows/:id` — single window detail
- `GET /windows/:id/context` — LLM-ready context object
- `GET /resources` — all windows with CPU/mem/power/net metrics
- `GET /timeline` — window lifecycle events

### Performance contract
5s polling idle, 1s when World View open. Thumbnails on-demand only. Target: <0.5% CPU, <50MB RAM idle.

Ref: GRIDFORGE_V2_DESIGN.md § Domain 1, § API Reference
""",
    },
    {
        "title": "feat(v2/p2): World View Panel",
        "body": """## Phase 2 — Workspace Overview UI

Floating, pinnable SwiftUI panel (NSPanel, non-activating, .floating level) showing all windows as a live list/card/grid view. The command center for workspace awareness.

### Layout
- Sidebar: grouping axis selector (By App / Space / Group / Zone / Project / Flat)
- Main: scrollable window rows with resource badges
- Inspector: selected window metadata, sparklines, tabs, relationships (collapsible right panel)

### Per-window status badges
🔴 CPU threshold · 💾 Memory · ⚡ Power · 📹 Camera in use · 🎙 Mic in use · 🔊 Audio playing · 🌐 Network I/O · 🔗 Screen sharing · ⏸ Paused

### View modes
- **List** (default) — compact rows with badges
- **Card** — larger cards with live thumbnails (Screen Recording permission required)
- **Grid map** — spatial view matching actual display layout

### Interaction
- Click → focus window; right-click → context menu; double-click title → inline rename
- Cmd+click multi-select → bulk actions; drag row → assign to group
- ⌘K → Command Palette prefilled with selected window context

### Inspector tabs
Overview · Resources (sparklines) · Tabs/Content · History (heatmap) · Relations · Actions

### Pinning
Dock to left/right edge of any display or float freely; position persisted per display profile.

Ref: GRIDFORGE_V2_DESIGN.md § Domain 2, § Domain 3
""",
    },
    {
        "title": "feat(v2/p3): Window Controls & Groups",
        "body": """## Phase 3 — Full Control Surface

Complete window management controls accessible from World View, context menus, API, and Command Palette.

### Individual window controls
- **Name** — inline rename in World View; persisted pattern-matched display name
- **Tag** — free-form tags (project, status, context); filter/group by tag
- **Move to space** — CGS-based Mission Control space assignment
- **Move to display** — cross-display window relocation
- **Resize to preset** — snap to any saved layout slot from World View
- **Focus** — foreground bring
- **Hide / Show** — NSRunningApplication hide/unhide
- **Pause / Resume** — SIGSTOP/SIGCONT (with Electron watchdog warning dialog)
- **Quit / Force-quit** — terminate / forceTerminate with confirmation for unsaved docs
- **Close window** — AX close button action

### Window Groups
A named collection of windows treated as a unit.

- Create group from current selection or by rule (app, tag, title pattern, space)
- **Snap group** — apply saved layout to all group members simultaneously
- **Tile group** — auto-tile group windows across a zone or display
- **Focus group** — foreground all group members
- **Suspend group** — SIGSTOP all; Resume group — SIGCONT all
- **Save group layout** — snapshot current positions as group layout
- **Restore group layout** — reposition to saved positions

### API additions
`POST /windows/:id/tag`, `POST /windows/:id/pause`, `POST /windows/:id/resume`
`POST /windows/:id/kill`, `POST /windows/:id/hide`, `POST /windows/:id/show`
`GET /groups`, `POST /groups`, `POST /groups/:id/snap`, `POST /groups/:id/suspend`

Ref: GRIDFORGE_V2_DESIGN.md § Domain 4, § Domain 5
""",
    },
    {
        "title": "feat(v2/p4): Grid Overlay Enhancements",
        "body": """## Phase 4 — Enhanced Grid & Snap

Upgrade the existing grid overlay and snap system with richer visual feedback, live previews, and multi-monitor intelligence.

### Visual improvements
- **Snap preview ghost** — translucent outline showing where window will land before release
- **Zone labels** — optional label overlay showing zone names
- **Conflict highlighting** — when a window would overlap an occupied zone, highlight both
- **Occupied zone dim** — zones containing a window shown with subtle fill vs. empty zones
- **Multi-display stitched view** — grid overlay spans all displays in a unified coordinate view

### Snap behavior
- **Soft snap zones** — configurable snap radius (currently threshold-based)
- **Snap to group** — when snapping a window, offer to add it to the zone's current group
- **Inertial snapping** — drag speed affects which zone wins (slow drag = nearest, fast = intentional override)

### Layout slot enhancements
- Named zones (e.g. "terminal", "browser", "editor", "reference")
- Zone metadata: preferred apps, tag filter, MacWatch alert anchor

### Keyboard snap
Extend existing shortcut system with:
- Snap to zone by name via Command Palette
- Cycle window through zone sequence
- Snap all windows in group to their assigned zones

Ref: GRIDFORGE_V2_DESIGN.md § Domain 10
""",
    },
    {
        "title": "feat(v2/p5): Command Palette",
        "body": """## Phase 5 — ⌘K Command Palette

System-wide command palette (NSPanel, .screenSaver level, global hotkey) for instant window and workspace operations.

### Activation
- Global hotkey (default ⌘⌥Space, configurable)
- From World View row: ⌘K prefills with selected window

### Command categories
1. **Window actions** — focus, rename, tag, move to space/display, snap to zone, pause, quit
2. **Layout commands** — apply layout, save layout, restore snapshot
3. **Group commands** — create group, add to group, snap group, suspend group
4. **Navigation** — switch to app, switch to space, focus last
5. **Search** — fuzzy search by window title / app / tag / document path
6. **System** — trigger MacWatch scan, open NetWatch status, toggle World View

### Fuzzy search
- Searches title, app name, tags, document path, URL (for browsers/terminals)
- Recent commands floated to top
- Context-aware: if a window is selected in World View, window-scoped commands appear first

### API endpoint
`POST /command` — accepts natural language command string; routes to appropriate action(s). Primary LLM integration surface.

### Plugin skill
`gridforge-command` — run any GridForge command conversationally via the API

Ref: GRIDFORGE_V2_DESIGN.md § Domain 9
""",
    },
    {
        "title": "feat(v2/p6): Timeline & Window Analytics",
        "body": """## Phase 6 — Temporal Awareness & Analytics

Surface when windows were opened, how long they've been running, focus history, and usage trends.

### Timeline data model
All events logged to `window_events` SQLite table:
- Window open / close / focus-gained / focus-lost / snap / move / resize / tag / group-assign / pause / resume

### Window-level analytics
- Total focus time (session, day, week)
- Focus frequency (how often switched to)
- Last active timestamp
- Age (time since launch)
- Session count (how many times reopened)

### World View displays
- Age badge: "2h 14m" shown on window row
- Focus sparkline: last 4h activity strip in Inspector
- Heatmap: daily/hourly grid in Inspector History tab

### Analytics panel (new tab in World View or standalone)
- App-level focus distribution: pie/bar chart of where time went
- Top windows by focus time
- Zombie detection: windows open >24h with <1min focus → highlight in World View
- Productivity patterns: peak hours, context-switch frequency

### API endpoints
`GET /timeline` — all events with optional ?windowId, ?type, ?since, ?until
`GET /analytics/focus` — aggregated focus stats
`GET /analytics/app/:bundleID` — per-app analytics

### MacWatch bridge
When MacWatch CPU/memory spike events arrive via NSDistributedNotificationCenter, they are correlated with window_events timeline to identify culprit (e.g. "Electron spiked 120% CPU when window X was focused").

Ref: GRIDFORGE_V2_DESIGN.md § Domain 7
""",
    },
    {
        "title": "feat(v2/p7): Automation Engine v2",
        "body": """## Phase 7 — Rules & Automation Engine

Declarative rule engine for automatic window management triggered by lifecycle events.

### Rule anatomy
```
trigger: window.opened AND app.bundleID == "com.github.atom"
conditions: display.isPrimary == true
actions:
  - snap: zone="editor"
  - addToGroup: "dev"
  - tag: "work"
```

### Trigger types
- `window.opened(bundleID?, titlePattern?)` — new window matching criteria
- `window.focused(bundleID?, titlePattern?)` — window brought to foreground
- `window.closed` — window closed
- `resource.cpu_exceeded(threshold, duration)` — sustained CPU spike
- `resource.memory_exceeded(threshold)` — memory threshold
- `display.connected(displayName?)` — display plug/unplug
- `space.changed(spaceIndex?)` — Mission Control space switch
- `macwatch.alert(sensor?, severity?)` — MacWatch alert received
- `time.cron(expression)` — scheduled trigger

### Action types
- `snap(zone)` — apply layout slot
- `addToGroup(groupName)` — add to named group
- `tag(tagName)` — apply tag
- `pause()` / `resume()` — SIGSTOP/SIGCONT
- `notify(message)` — macOS notification
- `apiCall(endpoint, body)` — call external/local API

### Per-app rules (extend existing system)
Existing perAppRules extended to full rule objects; legacy format auto-migrated.

### API
`GET /automations` — list rules
`POST /automations` — create rule
`PUT /automations/:id` — update
`DELETE /automations/:id` — delete
`POST /automations/:id/test` — dry-run against current window state

Ref: GRIDFORGE_V2_DESIGN.md § Domain 8
""",
    },
    {
        "title": "feat(v2/p8): MacWatch & NetWatch Integration",
        "body": """## Phase 8 — Sister App Coordination

Bi-directional event bus between GridForge, MacWatch, and NetWatch via NSDistributedNotificationCenter + shared SQLite read path.

### Architecture
- **Event bus**: NSDistributedNotificationCenter used for real-time signals (already used by MacWatch and NetWatch for their own internal events)
- **Shared SQLite**: GridForge reads MacWatch DB (`~/.macwatch/macwatch.db`) and NetWatch DB (`~/network_tests/netwatch.db`) for historical context — read-only, no shared write path

### MacWatch → GridForge signals
| Event | GF Action |
|-------|-----------|
| `com.macwatch.cpu.spike {pid, pct}` | Highlight offending window in World View with 🔴 badge; optionally offer to pause |
| `com.macwatch.memory.spike {pid, bytes}` | Badge in World View + Inspector alert |
| `com.macwatch.thermal.warning {level}` | World View header banner; automation trigger available |
| `com.macwatch.power.drain {pid}` | ⚡ badge on offending window |

### NetWatch → GridForge signals
| Event | GF Action |
|-------|-----------|
| `com.netwatch.connectivity.lost` | World View shows global 🌐 OFFLINE banner |
| `com.netwatch.latency.spike {ms}` | World View badge on network-active windows |
| `com.netwatch.incident.created {path}` | Notify + store in window_events for correlation |

### GridForge → MacWatch/NetWatch
`com.gridforge.space.changed`, `com.gridforge.window.paused`, `com.gridforge.window.killed` — for cross-tool timeline correlation.

### Companion API surface
`GET /macwatch/status` — proxy current MacWatch sensor summary
`GET /netwatch/status` — proxy current NetWatch connectivity status

Ref: GRIDFORGE_V2_DESIGN.md § MacWatch/NetWatch Integration
""",
    },
    {
        "title": "feat(v2/p9): Streaming API & Plugin Skill Expansion",
        "body": """## Phase 9 — Real-time API & Plugin Layer

Upgrade the companion server from polling-only to streaming, and expand the plugin skill set from 4 → ~30 skills.

### Streaming (Server-Sent Events)
`GET /stream` — SSE endpoint pushing:
- `window.opened / closed / focused / moved / resized / tagged / grouped`
- `resource.update {windowId, cpu, mem, power}` (1s cadence when subscribed)
- `macwatch.alert {sensor, value, severity}`
- `netwatch.event {type, detail}`
- `automation.fired {ruleId, windowId, actions}`

Client connects once; receives live event stream. Used by plugin skills and external tooling.

### New companion API endpoints (complete list additions)
- Window: GET/POST `/windows/:id/name`, `/windows/:id/tags`, `/windows/:id/pause`, `/windows/:id/resume`, `/windows/:id/kill`, `/windows/:id/move`, `/windows/:id/thumbnail`
- Groups: full CRUD on `/groups`
- Spaces: `GET /spaces`, `POST /windows/:id/move-to-space/:index`
- Displays: `GET /displays`, `POST /windows/:id/move-to-display/:id`
- Automations: full CRUD on `/automations`
- Analytics: `/analytics/focus`, `/analytics/app/:id`, `/analytics/zombies`
- Bridge: `/macwatch/status`, `/netwatch/status`
- Command: `POST /command` (NL routing)
- Stream: `GET /stream` (SSE)

### New gridforge-companion plugin skills
**Observation:** gridforge-windows, gridforge-window-detail, gridforge-resources, gridforge-timeline, gridforge-analytics, gridforge-zombies, gridforge-search

**Control:** gridforge-name, gridforge-tag, gridforge-snap-window, gridforge-pause, gridforge-resume, gridforge-kill, gridforge-move-space, gridforge-move-display

**Groups:** gridforge-groups, gridforge-group-create, gridforge-group-snap, gridforge-group-suspend

**Automation:** gridforge-automations, gridforge-automation-create

**Intelligence:** gridforge-command, gridforge-context (LLM-optimized workspace summary), gridforge-macwatch-bridge, gridforge-netwatch-bridge

Ref: GRIDFORGE_V2_DESIGN.md § API Reference, § Plugin Skills
""",
    },
    {
        "title": "feat(v2/p10): Space & Display Intelligence",
        "body": """## Phase 10 — Mission Control & Multi-Display Awareness

First-class Mission Control space support and intelligent multi-display layout management.

### Space awareness
- Track which space each window is on (CGS private API: CGSGetWindowWorkspace or CGSSpaces)
- `spaceIndex` field in enriched window model
- World View grouping axis: "By Space" shows windows organized by Mission Control space
- Space names (user-defined in System Settings) surfaced where available

### Cross-space operations
- Move window to named/indexed space: `POST /windows/:id/move-to-space/:index`
- Move group to space: `POST /groups/:id/move-to-space/:index`
- Snap group across spaces: assign each member a target space + zone

### Display profiles (extend existing)
Existing display profiles extended with:
- Space-slot mapping: which space to activate on which display when profile is applied
- Per-space layout: different grid configuration per Mission Control space
- Display hotplug rules: auto-apply profile when display arrangement matches

### Multi-display layout tools
- `GET /displays` — list all connected displays with resolution, scaling, arrangement
- `POST /layout/redistribute` — rebalance open windows across displays per current profile
- World View: display tabs or a stitched spatial view showing all windows across all displays

### Private API strategy
CGS functions (CGSMoveWindowToSpace, CGSGetActiveSpace) are used by Moom, BTT, Magnet, Yoink. Ship behind a feature flag; document clearly in README that these are private APIs. Provide fallback (drag-to-space via AppleScript) for cases where they break across macOS versions.

Ref: GRIDFORGE_V2_DESIGN.md § Domain 11, § Technical Notes
""",
    },
    {
        "title": "discussion(v2): Open Questions & Architecture Decisions",
        "body": """## Open Questions for v2 Architecture

Discussion issue to track unresolved design decisions before implementation.

### OQ-1: SIGSTOP/SIGCONT safety
SIGSTOP pauses the entire process. Electron apps (Claude, VS Code, Slack) use watchdog timers that may fire when paused, causing crashes or data loss on SIGCONT. Mitigation options:
- Blocklist of known-unsafe bundleIDs
- Warning dialog before pausing any Electron app
- Use `NSRunningApplication.hide()` as a softer alternative (hides but doesn't pause)
**Decision needed:** What's the right pause UX for Electron apps?

### OQ-2: CGS private API versioning
CGS APIs (CGSMoveWindowToSpace, etc.) have broken across macOS minor versions before. Strategy options:
- Ship behind feature flag, disable on failure, warn user
- Test on each macOS release via CI
- Skip CGS entirely and use AppleScript drag-to-space fallback (slower, no API control)
**Decision needed:** Feature-flag or skip for v2.0?

### OQ-3: Screen Recording permission UX
Live thumbnails and window sharing state detection both require Screen Recording permission, which is a heavy ask for users who just want snapping. Options:
- Request lazily (only when user enables thumbnails in settings)
- Separate "Enhanced mode" onboarding that bundles Screen Recording + Accessibility
**Decision needed:** Lazy or upfront?

### OQ-4: MacWatch/NetWatch SQLite read path
Reading another app's SQLite DB directly is efficient but creates a coupling risk if either app changes its schema. Alternatives:
- Direct read (current plan) — fast, no IPC overhead, fragile to schema changes
- Versioned schema views — each app exports a stable `v_macwatch_export` view
- REST bridge — each app exposes status endpoint, GF polls it
**Decision needed:** Which coupling strategy?

### OQ-5: World View layout default
Should World View default to List (minimal, fast) or Card (rich, requires Screen Recording)?
Should it auto-dock or float?

### OQ-6: GRDB vs raw libsqlite3
v1 uses raw libsqlite3. v2 schema is more complex (5 new tables, timeline queries). GRDB adds ~500KB but provides type-safe queries, migrations, and observe(). Worth the dependency?

### OQ-7: Plugin skill distribution
v2 adds ~26 new skills to the gridforge-companion plugin. Options:
- Single plugin (one install, bigger)
- Split: gridforge-observe (read-only) + gridforge-control (write) + gridforge-intel
**Decision needed:** Before Phase 9 implementation.

_Link relevant PRs and decisions here as they're made._
""",
    },
]

results = []
for issue in issues:
    cmd = [GH, "issue", "create",
           "--repo", REPO,
           "--title", issue["title"],
           "--body", issue["body"],
           "--label", "enhancement"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        url = result.stdout.strip()
        results.append(f"OK  {issue['title'][:60]}  →  {url}")
    else:
        results.append(f"ERR {issue['title'][:60]}  :  {result.stderr.strip()[:120]}")
    print(results[-1], flush=True)

print("\n--- SUMMARY ---")
ok = sum(1 for r in results if r.startswith("OK"))
err = sum(1 for r in results if r.startswith("ERR"))
print(f"{ok} filed, {err} errors")
