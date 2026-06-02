---
name: gridforge-ship
description: Build, install, tag, and ship GridForge. Runs build_app.sh, bumps Info.plist, commits, tags, pushes to GitHub, creates release. Use when Louis says: ship gridforge, build gridforge, install gridforge, new gridforge version, gridforge-ship, rebuild gridforge.
---

# GridForge Ship

Ship GridForge: build → install → git tag → push → GitHub release.

## Required env / tools
- Xcode Command Line Tools (`swift build`)
- `gh` CLI authenticated to `lswingrover`
- Source: `~/Developer/gridforge/`

## Steps

### Step 1 — Confirm working directory is clean
```bash
cd ~/Developer/gridforge
git status --porcelain
```
If dirty: ask Louis to commit or stash first, unless `--dry-run`.

### Step 2 — Determine version
- If Louis specified a version: use it.
- Otherwise: read `CFBundleShortVersionString` from `Info.plist`, auto-patch-bump (+0.0.1).

### Step 3 — Run ship script
```
do shell script "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH && python3 ~/Developer/gridforge/ship_gridforge.py [--version X.X.X] [--notes '...'] > /tmp/gridforge_ship.txt 2>&1; true"
```
Then read `/tmp/gridforge_ship.txt` in a separate call. Do NOT retry on non-zero exit — read the output first.

### Step 4 — Verify install
```
do shell script "ls -la /Applications/GridForge.app/Contents/MacOS/GridForge"
```
Confirm executable is present and timestamp is fresh.

### Step 5 — Confirm GitHub release
```
do shell script "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH && gh release view --repo lswingrover/gridforge 2>&1"
```

### Step 6 — Report
Surface: new version, install path, GitHub release URL.
If any step failed: surface the exact error from /tmp/gridforge_ship.txt.

## Notes
- NEVER call `build_app.sh` or `ship_gridforge.py` directly from the Skill and then assume success from exit code.
- ALWAYS redirect output to /tmp/gridforge_ship.txt and read it back (OSASCRIPT SHIP INVOCATION convention, 2026-06-01).
- Install target is `/Applications` — NEVER `~/Applications`.
