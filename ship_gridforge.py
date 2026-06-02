#!/usr/bin/env python3
"""GridForge ship script
Usage: python3 ship_gridforge.py [--version X.X.X] [--notes "release notes"]
Builds, installs, tags, and pushes to GitHub.
"""
import subprocess, sys, re, os, argparse, tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
APP_NAME   = "GridForge"
REPO_SLUG  = "lswingrover/gridforge"


def run(cmd, capture=False, check=True):
    print(f"  $ {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    if capture:
        r = subprocess.run(cmd, capture_output=True, text=True, check=check,
                           shell=isinstance(cmd, str))
        return r.stdout.strip()
    subprocess.run(cmd, check=check, shell=isinstance(cmd, str))
    return ""


def bump_plist_version(version: str, build: str):
    plist   = SCRIPT_DIR / "Info.plist"
    content = plist.read_text()
    content = re.sub(
        r'(<key>CFBundleShortVersionString</key>\s*<string>)[^<]*(</string>)',
        rf'\g<1>{version}\g<2>', content)
    content = re.sub(
        r'(<key>CFBundleVersion</key>\s*<string>)[^<]*(</string>)',
        rf'\g<1>{build}\g<2>', content)
    plist.write_text(content)


def current_version():
    plist = (SCRIPT_DIR / "Info.plist").read_text()
    m = re.search(r'<key>CFBundleShortVersionString</key>\s*<string>([^<]+)</string>', plist)
    return m.group(1) if m else "1.0.0"


def next_patch(version: str) -> str:
    parts     = version.split(".")
    parts[-1] = str(int(parts[-1]) + 1)
    return ".".join(parts)


def zip_app(version: str) -> Path:
    # GH#17: gh release create requires a file, not a directory.
    # Use ditto for macOS-correct .app bundling (preserves resource forks + symlinks).
    app_src  = Path(f"/Applications/{APP_NAME}.app")
    zip_path = Path(tempfile.gettempdir()) / f"{APP_NAME}-{version}.zip"
    if zip_path.exists():
        zip_path.unlink()
    subprocess.run(
        ["ditto", "-c", "-k", "--keepParent", str(app_src), str(zip_path)],
        check=True
    )
    size_mb = zip_path.stat().st_size / 1_048_576
    print(f"  ✓ zipped → {zip_path}  ({size_mb:.1f} MB)")
    return zip_path


def main():
    parser = argparse.ArgumentParser(description="Ship GridForge")
    parser.add_argument("--version", help="Version string, e.g. 1.1.0. Defaults to auto-patch-bump.")
    parser.add_argument("--notes",   help="Release notes", default="")
    parser.add_argument("--dry-run", action="store_true", help="Build only; skip git tag + push")
    args = parser.parse_args()

    os.chdir(SCRIPT_DIR)

    # Dirty check
    dirty = run(["git", "status", "--porcelain"], capture=True)
    if dirty and not args.dry_run:
        print("⚠  Uncommitted changes — commit or stash first.")
        sys.exit(1)

    # Version
    old_ver = current_version()
    new_ver = args.version or next_patch(old_ver)
    build   = run(["git", "rev-list", "--count", "HEAD"], capture=True, check=False) or "1"

    print(f"\n▶ GridForge ship: {old_ver} → {new_ver}  (build {build})")

    # Bump Info.plist
    bump_plist_version(new_ver, build)
    print(f"  ✓ Info.plist bumped to {new_ver}")

    # Build + install to /Applications
    print("\n── Build ──────────────────────────────────────────────────")
    run(["bash", "build_app.sh"])

    if args.dry_run:
        print("\n[dry-run] Skipping git commit, tag, push.")
        return

    # Commit version bump
    print("\n── Git ────────────────────────────────────────────────────")
    run(["git", "add", "Info.plist"])
    run(["git", "commit", "-m", f"chore: bump to v{new_ver}"])

    # Tag + push
    tag = f"v{new_ver}"
    run(["git", "tag", "-a", tag, "-m", f"GridForge {tag}"])
    run(["git", "push", "origin", "main"])
    run(["git", "push", "origin", tag])

    # GitHub release — zip the .app first (GH#17)
    notes    = args.notes or f"GridForge {tag}"
    zip_path = None
    try:
        print("\n── GitHub Release ─────────────────────────────────────────")
        zip_path = zip_app(new_ver)
        gh = "/opt/homebrew/bin/gh"
        run([gh, "release", "create", tag,
             str(zip_path),
             "--title", f"GridForge {tag}",
             "--notes", notes])
        print(f"  ✓ GitHub release {tag} created")
    except Exception as e:
        print(f"  ⚠ GitHub release failed (create manually): {e}")
    finally:
        if zip_path and zip_path.exists():
            zip_path.unlink()

    print(f"\n✅  GridForge {tag} shipped → https://github.com/{REPO_SLUG}/releases/tag/{tag}")


if __name__ == "__main__":
    main()
