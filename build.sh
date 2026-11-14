#!/bin/bash
# Builds "~/Applications/Dia Arc.app": a re-signed copy of /Applications/Dia.app
# with arcpatches.dylib injected. Re-run after every Dia update.
#
#   ./build.sh            build and install
#   ./build.sh --launch   build, install, and open it
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="/Applications/Dia.app"
DEST="$HOME/Applications/Dia Arc.app"
OUT="$HERE/build"

if pgrep -f "$DEST/Contents/MacOS/Dia" >/dev/null; then
    echo "Quit Dia Arc first." >&2
    exit 1
fi

mkdir -p "$OUT"
# Every .m under src/ (core, browsers, features); headers resolve via -I.
SOURCES=()
while IFS= read -r f; do SOURCES+=("$f"); done < <(find "$HERE/src" -name '*.m' | sort)
clang -dynamiclib -arch arm64 -fobjc-arc -O2 -Wall -Wno-unused-function \
    -framework AppKit -framework QuartzCore -lsqlite3 -DARCPATCHES_VERSION="\"$(cat "$HERE/VERSION")\"" \
    -I"$HERE/src/core" -I"$HERE/src/browsers/dia" \
    -o "$OUT/arcpatches.dylib" "${SOURCES[@]}"
codesign -f -s - "$OUT/arcpatches.dylib"

mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -cR "$SRC" "$DEST"
cp "$OUT/arcpatches.dylib" "$DEST/Contents/Frameworks/arcpatches.dylib"

PLIST="$DEST/Contents/Info.plist"
# Load the patch from the binary itself (weak load command), not DYLD_INSERT_LIBRARIES.
clang -O2 -o "$OUT/insert-dylib" "$HERE/tools/insert-dylib.c"
codesign --remove-signature "$DEST/Contents/MacOS/Dia"
"$OUT/insert-dylib" "$DEST/Contents/MacOS/Dia" "@executable_path/../Frameworks/arcpatches.dylib"
/usr/libexec/PlistBuddy -c "Delete :LSEnvironment" "$PLIST" 2>/dev/null || true
# Sparkle would replace this copy with a stock build; update the regular Dia instead.
/usr/libexec/PlistBuddy -c "Set :SUEnableAutomaticChecks false" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool false" "$PLIST"
# Display name only: Dia names its profile folder after CFBundleName.
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Dia Arc" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Dia Arc" "$PLIST"

# Ad-hoc signature. Restricted entitlements (keychain groups, associated domains,
# passkeys) can't be kept without Dia's provisioning profile, so they're dropped.
codesign -f -s - --options runtime --entitlements "$HERE/entitlements.plist" "$DEST"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
echo "Built: $DEST"

if [[ "${1:-}" == "--launch" ]]; then
    open "$DEST"
fi
