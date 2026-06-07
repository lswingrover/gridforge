#!/usr/bin/env python3
"""Sync GridForge v2 design session to ~/Documents/Claude/. Run once."""
import pathlib

home = pathlib.Path.home()

# --- 1. Today's session log ---
log_dir = home / "Documents/Claude/logs"
log_dir.mkdir(parents=True, exist_ok=True)
log_path = log_dir / "2026-06-06.md"

log_entry = "\n### 19:13 [Cowork] · GridForge v2 — Full Feature Design + GH Issues Filed\n"
log_entry += "**What:** Designed comprehensive v2 feature set across 12 domains: Enriched Window Model "
log_entry += "(AX+CGS+NSRunningApplication), World View Panel (NSPanel floating), Window Controls "
log_entry += "(SIGSTOP/SIGCONT, group ops), Grid Overlay Enhancements, Command Palette "
log_entry += "(global hotkey, /command NL endpoint), Timeline & Analytics (SQLite window_events), "
log_entry += "Automation Engine v2 (declarative rules), MacWatch/NetWatch Integration "
log_entry += "(NSDistributedNotificationCenter + SQLite read bridge), Streaming API (SSE, 60+ endpoints), "
log_entry += "Space & Display Intelligence (CGS private APIs). "
log_entry += "Filed 11 GH issues (#18-#28): 10 phases + open questions discussion.\n"
log_entry += "**Deliverable:** ~/Developer/gridforge/GRIDFORGE_V2_DESIGN.md, scripts/file_v2_issues.py\n"
log_entry += "**Follow-up:** Begin Phase 1 (Enriched Window Model) — branch feat/v2-window-model\n"
log_entry += "**Complexity:** red\n"

if log_path.exists():
    existing = log_path.read_text()
    if "19:13" not in existing:
        log_path.write_text(existing + log_entry)
        print("LOG: appended to 2026-06-06.md")
    else:
        print("LOG: entry already present")
else:
    log_path.write_text("# Claude Session Log -- 2026-06-06\n" + log_entry)
    print("LOG: created 2026-06-06.md")

# --- 2. Update gridforge/context.md ---
ctx_path = home / "Documents/Claude/gridforge/context.md"
if not ctx_path.exists():
    print("CTX: context.md not found, skipping")
else:
    content = ctx_path.read_text()
    content = content.replace(
        "Last updated: 2026-06-03 (v1.2.6)",
        "Last updated: 2026-06-06 (v2 design)"
    )
    v2_block = "\n## v2 Design (filed 2026-06-06)\n"
    v2_block += "Design document: ~/Developer/gridforge/GRIDFORGE_V2_DESIGN.md\n"
    v2_block += "GH issues: #18-#28 in lswingrover/GridForge\n"
    v2_block += "- P1 #18: Enriched Window Model & Core API Expansion\n"
    v2_block += "- P2 #19: World View Panel\n"
    v2_block += "- P3 #20: Window Controls & Groups\n"
    v2_block += "- P4 #21: Grid Overlay Enhancements\n"
    v2_block += "- P5 #22: Command Palette\n"
    v2_block += "- P6 #23: Timeline & Window Analytics\n"
    v2_block += "- P7 #24: Automation Engine v2\n"
    v2_block += "- P8 #25: MacWatch & NetWatch Integration\n"
    v2_block += "- P9 #26: Streaming API & Plugin Skill Expansion\n"
    v2_block += "- P10 #27: Space & Display Intelligence\n"
    v2_block += "- OQ #28: Open Questions & Architecture Decisions\n"
    v2_block += "Next: Phase 1 on branch feat/v2-window-model\n"

    if "v2 Design" not in content:
        ctx_path.write_text(content + v2_block)
        print("CTX: updated context.md with v2 block")
    else:
        ctx_path.write_text(content)
        print("CTX: v2 block already present, date updated")

print("Done.")
