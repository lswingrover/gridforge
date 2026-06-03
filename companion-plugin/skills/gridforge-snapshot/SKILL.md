---
name: gridforge-snapshot
description: "Capture the current workspace state as a named snapshot, restore a previous snapshot, or list saved snapshots. Trigger phrases: \"save this layout\", \"capture my workspace\", \"snapshot my windows\", \"save as [name]\", \"restore [name]\", \"load my [name] layout\", \"what snapshots do I have\", \"list my snapshots\", \"gridforge snapshot\"."
---
# GridForge Snapshot

Capture and restore full workspace snapshots via the GridForge Companion API (port 14731).

A snapshot captures the complete workspace state: which windows are open, their sizes, positions, and which layout is active. Restoring a snapshot repositions all matching windows.

## Step 1 — Health Check

```bash
curl -s http://localhost:14731/health
```

If this fails: GridForge is not running. Tell the user to open /Applications/GridForge.app first.

## Step 2 — Determine Intent

- **"save / capture / snapshot [name]"** → Step 3: Capture
- **"restore / load / apply [name]"** → Step 4: Restore
- **"list / what snapshots"** → Step 5: List

## Step 3 — Capture Snapshot

```bash
curl -s -X POST http://localhost:14731/snapshot/capture \
  -H "Content-Type: application/json" \
  -d '{"name": "NAME"}'
```

Replace `NAME` with the user's chosen name (e.g. "work", "writing", "zoom").

Expected response:
```json
{
  "captured": true,
  "name": "work",
  "windowCount": 5,
  "layout": "3×3",
  "timestamp": "2026-06-02T18:00:00Z"
}
```

Report: "Snapshot '{name}' saved — captured {windowCount} windows in '{layout}' layout."

## Step 4 — Restore Snapshot

```bash
curl -s -X POST http://localhost:14731/snapshot/restore \
  -H "Content-Type: application/json" \
  -d '{"name": "NAME"}'
```

Expected response:
```json
{
  "restored": true,
  "name": "work",
  "windowsRestored": 5,
  "windowsMissing": 1
}
```

Report: "Restored '{name}' — {windowsRestored} windows repositioned, {windowsMissing} not found (app may not be open)."

If `windowsMissing > 0`, offer: "Say 'snap my windows' after opening the missing apps."

## Step 5 — List Snapshots

```bash
curl -s http://localhost:14731/snapshots
```

Expected response: array of snapshot objects with `name`, `windowCount`, `layout`, `timestamp`.

Present as a compact table:
```
Name       Windows  Layout      Saved
work       5        3×3         Jun 2, 18:00
writing    3        Side-by-Side Jun 1, 10:22
zoom       2        Full Screen  May 31, 09:15
```

Offer: "Say 'restore [name]' to load one."

## Error Handling

- Snapshot name not found on restore: list available snapshots.
- `{"captured": false}`: no windows to snapshot. Open some apps first.
- Connection refused: GridForge is not running.
