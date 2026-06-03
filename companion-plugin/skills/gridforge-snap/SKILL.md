---
name: gridforge-snap
description: "Snap all windows to the current GridForge layout, or apply a specific named layout. Trigger phrases: \"snap my windows\", \"arrange my windows\", \"apply grid\", \"snap to layout\", \"gridforge snap\", \"apply [layout name] layout\", \"switch to [layout name]\", \"use the side-by-side layout\"."
---
# GridForge Snap

Trigger an immediate window snap or apply a specific named layout via the GridForge Companion API (port 14731).

## Step 1 — Health Check

```bash
curl -s http://localhost:14731/health
```

If this fails: GridForge is not running. Tell the user to open /Applications/GridForge.app first.

## Step 2 — Determine Action

**If the user said "snap my windows" (no specific layout):**
→ Go to Step 3a — snap to current layout.

**If the user named a layout (e.g. "apply Side-by-Side", "switch to 3×3"):**
→ Go to Step 3b — apply named layout.

## Step 3a — Snap to Current Layout

```bash
curl -s -X POST http://localhost:14731/snap
```

Expected response:
```json
{"snapped": true, "layout": "3×3", "windowCount": 4}
```

Report: "Snapped {windowCount} windows to {layout}."

## Step 3b — List Available Layouts (if layout name is ambiguous)

```bash
curl -s http://localhost:14731/layouts
```

If the user's layout name doesn't exactly match, fuzzy-match against the list. If still ambiguous, ask the user to pick from the list.

## Step 3c — Apply Named Layout

```bash
curl -s -X POST http://localhost:14731/apply \
  -H "Content-Type: application/json" \
  -d '{"layout": "NAME"}'
```

Replace `NAME` with the exact layout name from the layouts list.

Expected response:
```json
{"applied": true, "layout": "Side-by-Side", "windowCount": 3}
```

Report: "Applied '{layout}' — {windowCount} windows repositioned."

## Error Handling

- `404 Not Found` on `/apply`: the layout name doesn't exist. List available layouts for the user.
- `{"snapped": false}`: GridForge couldn't snap (no eligible windows). Check if any windows are open.
- Connection refused: GridForge is not running. Direct user to open /Applications/GridForge.app.
