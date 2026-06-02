#!/bin/bash
# GridForge build script
# Builds, bundles, signs (ad-hoc), and installs to /Applications
set -e

APP_NAME="GridForge"
BUNDLE_ID="com.lswingrover.gridforge"
VERSION="1.0.0"
BUILD="1"
INSTALL_DIR="/Applications"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "▶ GridForge build_app.sh v${VERSION}"
echo "  Source: ${SCRIPT_DIR}"
echo "  Target: ${INSTALL_DIR}/${APP_NAME}.app"
echo ""

# ── Step 1: Swift build ───────────────────────────────────────────────────────
echo "[1/7] swift build (release)…"
cd "${SCRIPT_DIR}"
swift build -c release 2>&1
EXEC=".build/release/${APP_NAME}"
[ -f "${EXEC}" ] || { echo "ERROR: executable not found at ${EXEC}"; exit 1; }
echo "      ✓ executable: ${EXEC}"

# ── Step 2: Bundle skeleton ───────────────────────────────────────────────────
echo "[2/7] Assembling .app bundle…"
APP_BUNDLE="${SCRIPT_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${EXEC}"            "${MACOS_DIR}/${APP_NAME}"
cp "${SCRIPT_DIR}/Info.plist" "${CONTENTS}/Info.plist"
sed -i '' "s|<string>1.0.0</string>|<string>${VERSION}</string>|g" "${CONTENTS}/Info.plist"
sed -i '' "s|<string>1</string>|<string>${BUILD}</string>|g"       "${CONTENTS}/Info.plist"
echo "      ✓ bundle skeleton ready"

# ── Step 3: Icon (placeholder if gridforge.icns missing) ─────────────────────
echo "[3/7] Icon…"
ICNS_SRC="${SCRIPT_DIR}/Resources/gridforge.icns"
if [ -f "${ICNS_SRC}" ]; then
    cp "${ICNS_SRC}" "${RESOURCES_DIR}/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${CONTENTS}/Info.plist" 2>/dev/null || true
    echo "      ✓ icon copied"
else
    echo "      ⚠ no icns found — placeholder icon (add Resources/gridforge.icns to fix)"
fi

# ── Step 4: Ad-hoc sign ───────────────────────────────────────────────────────
echo "[4/7] Signing (ad-hoc)…"
codesign --force --deep --sign - --options runtime "${APP_BUNDLE}" 2>&1
echo "      ✓ signed"

# ── Step 5: Strip legacy custom icon xattrs ───────────────────────────────────
echo "[5/7] Stripping icon xattrs…"
xattr -d com.apple.FinderInfo   "${APP_BUNDLE}" 2>/dev/null || true
xattr -d com.apple.ResourceFork "${APP_BUNDLE}" 2>/dev/null || true
echo "      ✓ clean"

# ── Step 6: Install to /Applications ─────────────────────────────────────────
echo "[6/7] Installing to ${INSTALL_DIR}…"
rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
cp -R "${APP_BUNDLE}" "${INSTALL_DIR}/"
echo "      ✓ installed"

# ── Step 7: Register with LaunchServices ─────────────────────────────────────
echo "[7/7] Registering with LaunchServices…"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true
killall Dock 2>/dev/null || true
echo "      ✓ registered"

echo ""
echo "✅  GridForge v${VERSION} installed → ${INSTALL_DIR}/${APP_NAME}.app"
echo "    Launch: open '${INSTALL_DIR}/${APP_NAME}.app'"
