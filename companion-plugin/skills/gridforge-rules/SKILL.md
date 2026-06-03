---
name: gridforge-rules
description: "View, create, update, or delete per-app GridForge rules — which grid layout each app uses when snapped. Trigger phrases: \"show my gridforge rules\", \"what are my per-app rules\", \"set [app] to use [layout]\", \"add a rule for [app]\", \"delete the rule for [app]\", \"remove [app] from gridforge\", \"gridforge rules\", \"per-app rules\"."
---
# GridForge Rules

Manage per-app grid rules via the GridForge Companion API (port 14731).

A per-app rule tells GridForge which layout to apply when a specific app's window is snapped. Rules are keyed by bundle ID (e.g. `com.apple.Safari`, `com.microsoft.VSCode`).

## Step 1 — Health Check

```bash
curl -s http://localhost:14731/health
```

If this fails: GridForge is not running. Tell the user to open /Applications/GridForge.app first.

## Step 2 — Determine Intent

- **"show / list / what rules"** → Step 3: List
- **"set / add / create rule for [app]"** → Step 4: Create / Update
- **"delete / remove rule for [app]"** → Step 5: Delete

## Step 3 — List All Rules

```bash
curl -s http://localhost:14731/rules
```

Expected response: array of rule objects.

Present as a compact table:
```
App              Bundle ID                    Layout
Safari           com.apple.Safari             Side-by-Side
Xcode            com.apple.dt.Xcode           Full Screen
Terminal         com.apple.Terminal           3×3
```

If no rules: "No per-app rules configured. Say 'set [app] to [layout]' to add one."

## Step 4 — Create or Update a Rule

If the user gave an app name (not a bundle ID), resolve it first:
```bash
curl -s "http://localhost:14731/rules/resolve?app=Safari"
```

Expected: `{"bundleId": "com.apple.Safari", "appName": "Safari"}`.

If resolution fails, ask the user to provide the exact bundle ID (findable via `osascript -e 'id of app "Safari"'`).

Then create/update the rule:
```bash
curl -s -X POST http://localhost:14731/rules \
  -H "Content-Type: application/json" \
  -d '{"bundleId": "BUNDLE_ID", "layout": "LAYOUT_NAME"}'
```

Expected response:
```json
{"created": true, "bundleId": "com.apple.Safari", "layout": "Side-by-Side"}
```

Report: "Rule set — Safari will snap to 'Side-by-Side'."

To get available layouts for the user to choose from:
```bash
curl -s http://localhost:14731/layouts
```

## Step 5 — Delete a Rule

Resolve the bundle ID if needed (same as Step 4), then:

```bash
curl -s -X DELETE "http://localhost:14731/rules/BUNDLE_ID"
```

Expected response:
```json
{"deleted": true, "bundleId": "com.apple.Safari"}
```

Report: "Rule for Safari removed — it will now use the default layout."

If `{"deleted": false, "reason": "not found"}`: no rule exists for that app.

## Error Handling

- Layout name not recognized: list available layouts via `/layouts`.
- Bundle ID resolution failure: ask user to check the app name spelling or provide bundle ID directly.
- Connection refused: GridForge is not running.
