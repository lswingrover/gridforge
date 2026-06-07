# Contributing to GridForge

GridForge is a macOS window layout manager — a native Swift app with a companion HTTP API on port 14731 and a Claude Cowork plugin. This document covers how to build, test, and extend it.

---

## Before you write code

1. **Read the README.** The layout model (named grids, per-app rules, snapshots), the Stage Manager notes, and the companion API contract are all documented there.
2. **Check the roadmap.**
3. **Build and run first.** Port 14731 must be free; check before starting.

---

## Environment

- macOS 14+ (Sonoma)
- Xcode 15+ / Swift 5.9+
- No external package manager dependencies
- Build target: `My Mac` (not simulator)
- Signing: **ad-hoc only**. Never reconfigure for App Store or notarization.
- The companion HTTP API runs on **localhost:14731** — this port is fixed and is part of the public API contract.

---

## Building

Open `gridforge.xcodeproj` in Xcode and press ⌘B. For releases, `build_app.sh` handles ad-hoc signing and bundle assembly (used by the `scotty:gridforge-ship` skill).

---

## Architecture principles

**The companion API is the interface.** Claude skills, shell scripts, and other tools drive GridForge through the HTTP API on port 14731. The API surface must remain stable. Any breaking change to the API is a major version bump and requires updating the companion plugin SKILL.md and the gridforge-companion plugin.

**Named layouts are the unit of work.** A layout has a name, a grid spec, and per-app assignments. Operations on layouts (snap, save snapshot, apply) are atomic. Do not expose partial state through the API.

**Stage Manager compatibility is non-negotiable.** Stage Manager changes how window management works. Any layout code must be tested with Stage Manager both on and off.

**SQLite for persistence.** Named layouts, per-app rules, and snapshots all persist in SQLite. Do not use UserDefaults for layout state.

**Menu bar first.** GridForge lives in the menu bar.

---

## Code standards

- **Swift 5.9+** with structured concurrency for all async work.
- **SwiftUI** for all UI. AppKit only where unavoidable.
- **No force unwraps** in new code.
- **No hardcoded paths** — use `FileManager` APIs.
- **No personal data in source.**
- **Port 14731 is a constant** — define it once, reference everywhere. Never scatter the number through the codebase.

---

## Companion API contract

The API (localhost:14731) serves the gridforge-companion plugin. Any endpoint you add or change:

1. Update the OpenAPI/route documentation in `docs/api.md`
2. Update the relevant SKILL.md in `companion/gridforge-companion.plugin/`
3. Rebuild the companion plugin with `scotty:gridforge-companion-ship`

Do not remove or rename existing endpoints without a deprecation cycle.

---

## Branch and commit conventions

Branches: `main` (stable), `feature/X`, `fix/X`, `refactor/X`

Commit format (Conventional Commits):

    feat(api): add GET /layouts/:name/preview endpoint
    fix(snap): handle windows with no title on Stage Manager
    refactor(db): extract layout repository into actor

---

## Testing

1. Build succeeds with zero warnings.
2. Run GridForge and verify the companion API responds: `curl http://localhost:14731/status`
3. Test snap with multiple monitors if your change touches multi-display logic.
4. Test with Stage Manager on and off.
5. Verify named layouts and snapshots survive an app restart (SQLite roundtrip).
6. Test the companion plugin with a real Claude session if you changed any API endpoint.

---

## Companion plugin

The Claude Cowork plugin lives in `companion/gridforge-companion.plugin/`. Run `scotty:gridforge-companion-ship` to rebuild after any SKILL.md change. The companion plugin version must stay in sync with the API it calls.

---

## Related

- [MacWatch](https://github.com/lswingrover/MacWatch) — system health monitor
- [NetWatch](https://github.com/lswingrover/NetWatch) — network health monitor
- [ClipWatch](https://github.com/lswingrover/ClipWatch) — clipboard monitor
- [Summon](https://github.com/lswingrover/Summon) — text expander (companion API on port 14732)
- [obrien](https://github.com/lswingrover/obrien) — Cowork companion plugin framework
