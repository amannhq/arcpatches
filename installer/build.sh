#!/bin/bash
# Builds ~/Applications/ArcPatches.app: the menu bar companion, with the arcpatches
# dylib bundled so it can patch Dia without a compiler.
#
#   ./installer/build.sh               build and install
#   ./installer/build.sh --launch      build, install, and open it
#   ./installer/build.sh --no-install  build only (build/ArcPatches.app; used by CI)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="$ROOT/build/ArcPatches.app"
DEST="$HOME/Applications/ArcPatches.app"
VERSION="$(cat "$ROOT/VERSION")"
REPO="${ARCPATCHES_REPO:-amannhq/arcpatches}"
# Public key that update downloads must be signed with (see scripts/make-update-key.sh).
UPDATE_KEY="${ARCPATCHES_UPDATE_PUBLIC_KEY:-$(cat "$HERE/update-public-key.txt" 2>/dev/null || true)}"

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"

# The patch itself: every .m under src/ (core, browsers, features); headers resolve via -I.
SOURCES=()
while IFS= read -r f; do SOURCES+=("$f"); done < <(find "$ROOT/src" -name '*.m' | sort)
clang -dynamiclib -arch arm64 -fobjc-arc -O2 -Wall -Wno-unused-function \
    -framework AppKit -framework QuartzCore -lsqlite3 -DARCPATCHES_VERSION="\"$VERSION\"" \
    -I"$ROOT/src/core" -I"$ROOT/src/browsers/dia" \
    -o "$OUT/Contents/Resources/arcpatches.dylib" "${SOURCES[@]}"
cp "$ROOT/entitlements.plist" "$OUT/Contents/Resources/"
echo "$VERSION" > "$OUT/Contents/Resources/VERSION"

# The companion.
swiftc -O -swift-version 5 -module-name ArcPatches -target arm64-apple-macos14 \
    -o "$OUT/Contents/MacOS/ArcPatches" "$HERE"/Sources/*.swift

"$OUT/Contents/MacOS/ArcPatches" --make-icon "$OUT/Contents/Resources"

cat > "$OUT/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.amannhq.arcpatches</string>
  <key>CFBundleName</key><string>ArcPatches</string>
  <key>CFBundleExecutable</key><string>ArcPatches</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleURLTypes</key><array><dict>
    <key>CFBundleURLName</key><string>dev.amannhq.arcpatches</string>
    <key>CFBundleURLSchemes</key><array><string>arcpatches</string></array>
  </dict></array>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>ArcPatchesRepo</key><string>$REPO</string>
  <key>ArcPatchesUpdatePublicKey</key><string>$UPDATE_KEY</string>
</dict></plist>
EOF

codesign -f -s - "$OUT/Contents/Resources/arcpatches.dylib"
# Hardened runtime: DYLD_INSERT_LIBRARIES can't inject code that would inherit
# ArcPatches's App Management permission.
codesign -f -s - --options runtime "$OUT"

if [[ "${1:-}" == "--no-install" ]]; then echo "Built: $OUT"; exit 0; fi

if pgrep -fx "$DEST/Contents/MacOS/ArcPatches" >/dev/null; then pkill -fx "$DEST/Contents/MacOS/ArcPatches"; sleep 1; fi
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R "$OUT" "$DEST"
echo "Built: $DEST"

if [[ "${1:-}" == "--launch" ]]; then open "$DEST"; fi
