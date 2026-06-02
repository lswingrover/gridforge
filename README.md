# GridForge

A macOS window management app — Divvy-elegant, Lasso-deep, headless-ready.

## Features (v1.0)
- Visual drag-to-select grid overlay (configurable up to 20×20 per display)
- Keyboard shortcuts mapped to saved grid positions
- Multi-monitor support with per-display grid configs
- Named layouts with hotkey binding
- Window gap / spacing control
- Display profile auto-detection and auto-switch
- Per-app window placement rules
- Layout snapshots (save/restore full workspace state)
- Stage Manager compatible
- Full companion API (every UI action reachable via Claude/AI/SDK)

## Install
Download the latest release and move `GridForge.app` to `/Applications`.
Grant Accessibility permission when prompted.

Default hotkey: **⌘⇧G**

## Companion Plugin
Install `gridforge-companion.plugin` in Claude → Settings → Capabilities → Plugins.
Ask Claude: "put me in code mode" / "save this layout as meeting" / "what's my current layout?"

## Build from Source
```bash
git clone https://github.com/lswingrover/gridforge
cd gridforge
bash build_app.sh
```
Requires Xcode Command Line Tools.

## License
MIT
