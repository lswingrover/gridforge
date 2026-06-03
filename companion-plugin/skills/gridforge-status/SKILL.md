---
name: gridforge-status
description: "Check GridForge server status and current layout state. Shows whether the companion API is running, the active grid layout, connected displays, and app version. Trigger phrases: \"is GridForge running\", \"gridforge status\", \"what layout am I on\", \"what's my current grid\", \"check gridforge\", \"gridforge health\"."
---
# GridForge Status

Check whether the GridForge Companion API is running and surface the current window-management state.

## Companion API

GridForge exposes a local HTTP API on port **14731**.

```bash
curl -s http://localhost:14731/health
```

If this returns a connection error, GridForge is not running or the companion server is disabled. Tell the user to open GridForge from /Applications/GridForge.app and ensure the companion API is enabled in Preferences → Advanced.

## Step 1 — Health Check

```bash
curl -s http://localhost:14731/health
```

Expected response:
```json
{"running": true, "version": "1.3.0", "port": 14731}
```

If the response is a connection error: GridForge is not running. Stop and tell the user.

## Step 2 — Current Layout State

```bash
curl -s http://localhost:14731/state
```

Parse and surface:
- `activeLayout` — name of the currently active grid layout (e.g. "3×3", "Side-by-Side")
- `displays` — list of connected displays with resolution
- `managedWindows` — count of windows currently being managed
- `snapEnabled` — whether auto-snap is enabled

## Step 3 — List Available Layouts

```bash
curl -s http://localhost:14731/layouts
```

Surface the list of named layouts so the user knows what's available.

## Step 4 — Report

Present a compact status block:

```
GridForge v{version} — running on port 14731
Active layout : {activeLayout}
Managed windows: {managedWindows}
Auto-snap      : {snapEnabled}
Displays       : {display list}
Layouts available: {layout names, comma-separated}
```

If anything looks wrong (no managed windows when apps are open, snap disabled), offer to fix it:
- "Say 'snap my windows' to force a snap"
- "Say 'apply layout [name]' to switch layouts"
