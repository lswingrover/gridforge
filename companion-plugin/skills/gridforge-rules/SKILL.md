---
name: gridforge-rules
description: "View, create, update, or delete per-app GridForge rules — which grid layout each app uses when snapped. Trigger phrases: \"show my gridforge rules\", \"what are my per-app rules\", \"set [app] to use [layout]\", \"add a rule for [app]\", \"delete the rule for [app]\", \"remove [app] from gridforge\", \"gridforge rules\", \"per-app rules\"."
---

# GridForge Rules

Manage per-app grid rules via the GridForge Companion API (port 14731).

A per-app rule tells GridForge which grid position to apply when a specific app launches or gains focus.
Rules are keyed by bundle ID (e.g. `com.apple.Safari`, `com.microsoft.VSCode`).

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

Expected response: array of rule objects with `id`, `bundleId`, `displayId`, `selection`, `trigger`.

Present as a compact table:
```
Bundle ID                    Selection     Trigger
com.apple.Safari             0:0-2:4       launch
com.apple.dt.Xcode           3:0-6:4       focus
```

If no rules: "No per-app rules configured. Say 'set [app] to [layout]' to add one."

## Step 4 — Create or Update a Rule

First resolve the bundle ID if the user gave an app name:

```bash
curl -s "http://localhost:14731/rules/resolve?app=Safari"
```

Expected: `{"appName": "Safari", "bundleId": "com.apple.Safari"}`.

If the app is not running, ask the user to provide the bundle ID directly
(findable via `osascript -e 'id of app "Safari"'`).

Then create or update the rule. Provide **either** a `layout` name (uses that layout's grid position)
**or** an explicit `selection` + `displayId`:

```bash
# Option A: derive position from a named layout
curl -s -X POST http://localhost:14731/rules \
  -H "Content-Type: application/json" \
  -d '{"bundleId": "com.apple.Safari", "layout": "Side-by-Side"}'

# Option B: explicit grid selection (encoded as "colStart:rowStart-colEnd:rowEnd")
curl -s -X POST http://localhost:14731/rules \
  -H "Content-Type: application/json" \
  -d '{"bundleId": "com.apple.Safari", "selection": "0:0-3:4", "displayId": "1920x1080@2"}'
```

Expected response:
```json
{"bundleId": "com.apple.Safari", "created": true}
```

Report: "Rule set — [appName] will snap to [selection] on launch."

## Step 5 — Delete a Rule

Resolve the bundle ID if needed (same as Step 4), then:

```bash
curl -s -X DELETE "http://localhost:14731/rules/com.apple.Safari"
```

Expected response:
```json
{"bundleId": "com.apple.Safari", "deleted": true}
```

If `{"deleted": false, "reason": "not found"}`: no rule exists for that app.

## Error Handling

- Layout name not recognized: list available layouts via `/list-layouts`.
- Bundle ID resolution failure (`404`): the app is not running — ask user to provide the bundle ID or open the app first.
- Connection refused: GridForge is not running.
