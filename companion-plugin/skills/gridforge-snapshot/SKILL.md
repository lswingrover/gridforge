---
name: gridforge-snapshot
description: "Capture the current workspace state as a named snapshot, restore a previous snapshot, or list saved snapshots. Trigger phrases: \"save this layout\", \"capture my workspace\", \"snapshot my windows\", \"save as [name]\", \"restore [name]\", \"load my [name] layout\", \"what snapshots do I have\", \"list my snapshots\", \"gridforge snapshot\"."
---

# GridForge Snapshot

Capture and restore full workspace snapshots via the GridForge Companion API (port 14731).

A snapshot captures which windows are open, their sizes, and positions.
Restoring repositions all matching windows.

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

Expected response:
```json
{"captured": true, "name": "work", "windowCount": 5}
```

Report: "Snapshot '[name]' saved — captured [windowCount] windows."

## Step 4 — Restore Snapshot

```bash
curl -s -X POST http://localhost:14731/snapshot/restore \
  -H "Content-Type: application/json" \
  -d '{"name": "NAME"}'
```

Expected response:
```json
{"name": "work", "restored": true, "windowsMissing": 1, "windowsRestored": 5}
```

Report: "Restored '[name]' — [windowsRestored] windows repositioned, [windowsMissing] not found."
If `windowsMissing > 0`, offer: "Say 'snap my windows' after opening the missing apps."

## Step 5 — List Snapshots

```bash
curl -s http://localhost:14731/list-snapshots
```

Returns `[{id, name, entryCount, createdAt}]`.

Present as a compact table:
```
Name       Windows  Saved
work       5        2026-06-02T18:00:00Z
writing    3        2026-06-01T10:22:00Z
```

Offer: "Say 'restore [name]' to load one."

## Error Handling

- `{"captured": false}` or `{"restored": false}`: check the `error` field for details.
- Connection refused: GridForge is not running.
