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
→ Step 3a — snap to first/default layout.

**If the user named a layout (e.g. "apply Side-by-Side", "switch to 3×3"):**
→ Step 3b — apply named layout.

## Step 3a — Snap to Default Layout

```bash
curl -s -X POST http://localhost:14731/snap
```

Expected response:
```json
{"layout": "Side-by-Side", "snapped": true, "windowCount": 0}
```

If `{"snapped": false, "reason": "no layouts configured"}`: tell the user they need to save a layout
first via the GridForge UI, or say "save this layout as [name]".

## Step 3b — List Available Layouts (if needed)

```bash
curl -s http://localhost:14731/list-layouts
```

Fuzzy-match the user's layout name against the returned list. If ambiguous, ask the user to pick.

## Step 3c — Apply Named Layout

```bash
curl -s -X POST http://localhost:14731/apply-layout \
  -H "Content-Type: application/json" \
  -d '{"name": "LAYOUT_NAME"}'
```

Expected response:
```json
{"applied": "Side-by-Side", "ok": true}
```

Report: "Applied '[layout]'."

## Error Handling

- `{"ok": false}`: layout not found. Run Step 3b to list available layouts.
- Connection refused: GridForge is not running.
