---
name: gridforge-status
description: "Check GridForge server status and current layout state. Shows whether the companion API is running, the active grid layout, connected displays, and app version. Trigger phrases: \"is GridForge running\", \"gridforge status\", \"what layout am I on\", \"what's my current grid\", \"check gridforge\", \"gridforge health\"."
---

# GridForge Status

Check whether the GridForge Companion API is running and surface the current window-management state.

## Companion API

GridForge exposes a local HTTP API on port **14731**.

If `/health` returns a connection error, GridForge is not running or the companion server is disabled.
Tell the user to open /Applications/GridForge.app and ensure the companion API is enabled
in Preferences → Advanced.

## Step 1 — Health Check

```bash
curl -s http://localhost:14731/health
```

Expected response:
```json
{"port": 14731, "status": "ok", "version": "1.2.5"}
```

If `status` is not `"ok"` or the connection is refused: GridForge is not running. Stop and tell the user.

## Step 2 — Current State

```bash
curl -s http://localhost:14731/get-state
```

Parse and surface:
- `version` — app version string
- `activeDisplay` — current display profile key (e.g. "1920x1080@2")
- `layouts` — list of `{id, name}` saved named layouts
- `shortcuts` — list of `{keyCombo, selection, name}` keyboard shortcuts
- `snapshots` — list of `{id, name, entryCount}` saved snapshots

## Step 3 — List Available Layouts

```bash
curl -s http://localhost:14731/list-layouts
```

Returns `[{id, name, entries:[{bundleID, displayID, selection}]}]`.
Surface the layout names so the user knows what's available.

## Step 4 — Report

Present a compact status block:

```
GridForge v{version} — running on port 14731
Display profile : {activeDisplay}
Layouts         : {layout names, comma-separated}
Shortcuts       : {count}
Snapshots       : {count}
```

If layouts or shortcuts are empty, offer:
- "Say 'snap my windows' to apply a layout"
- "Say 'save this layout as [name]' to create one"
