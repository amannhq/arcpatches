#!/bin/bash
# Tests that need no copy of Dia (run in CI and locally).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
pass() { echo "ok   $1"; }

# 1. The patch and the companion compile without warnings.
SOURCES=()
while IFS= read -r f; do SOURCES+=("$f"); done < <(find "$ROOT/src" -name '*.m' | sort)
clang -dynamiclib -arch arm64 -fobjc-arc -O2 -Wall -Werror -Wno-unused-function \
    -framework AppKit -framework QuartzCore -lsqlite3 -DARCPATCHES_VERSION="\"test\"" \
    -I"$ROOT/src/core" -I"$ROOT/src/browsers/dia" \
    -o "$WORK/arcpatches.dylib" "${SOURCES[@]}"
pass "arcpatches.dylib builds"
swiftc -O -swift-version 5 -module-name ArcPatches -target arm64-apple-macos14 -o "$WORK/ArcPatches" "$ROOT"/installer/Sources/*.swift
pass "companion builds"

# 2. insert-dylib adds a weak load command and the binary still runs.
clang -O2 -o "$WORK/insert-dylib" "$ROOT/tools/insert-dylib.c"
printf '#include <stdio.h>\nint main(void){puts("hello");return 0;}\n' > "$WORK/hello.c"
clang -Wl,-headerpad,0x200 -o "$WORK/hello" "$WORK/hello.c"
codesign --remove-signature "$WORK/hello"
"$WORK/insert-dylib" "$WORK/hello" "@executable_path/missing.dylib" >/dev/null
"$WORK/insert-dylib" "$WORK/hello" "@executable_path/missing.dylib" | grep -q "already present"
codesign -f -s - "$WORK/hello"
otool -l "$WORK/hello" | grep -A2 LC_LOAD_WEAK_DYLIB | grep -q "@executable_path/missing.dylib"
[ "$("$WORK/hello")" = "hello" ]
pass "insert-dylib: weak load command added once, binary still launches"

# 3. Update signatures: sign, verify, and reject a tampered file.
PUB="$(swift "$ROOT/tools/update-key.swift" generate "$WORK/key")"
echo "payload" > "$WORK/file"
ARCPATCHES_UPDATE_PRIVATE_KEY="$(cat "$WORK/key")" swift "$ROOT/tools/update-key.swift" sign "$WORK/file" > "$WORK/file.sig"
swift "$ROOT/tools/update-key.swift" verify "$WORK/file" "$WORK/file.sig" "$PUB" | grep -q OK
echo "tampered" > "$WORK/file"
if swift "$ROOT/tools/update-key.swift" verify "$WORK/file" "$WORK/file.sig" "$PUB" 2>/dev/null; then echo "FAIL tampered file verified"; exit 1; fi
pass "update signatures verify and reject tampering"

# 4. Nothing of Dia's is in the repository.
if git -C "$ROOT" ls-files | grep -qE '\.(icns|car)$|(^|/)Dia\.app(/|$)'; then
    echo "FAIL Dia assets found in the repository"; exit 1
fi
pass "no Dia binaries or artwork in the repository"

# 5. Browser registry and support matrix, against the dylib built in step 1 (docs/browsers.md).
clang -fobjc-arc -framework Foundation -I"$ROOT/src/core" -I"$ROOT/src" -o "$WORK/browsers" "$ROOT/tests/browsers.m" "$WORK/arcpatches.dylib"
if ! "$WORK/browsers" 2>"$WORK/browsers.log"; then grep FAIL "$WORK/browsers.log"; echo "FAIL browser registry"; exit 1; fi
pass "browser registry: Dia, Ardia and Chrome recognised, Arc excluded, Ardia switches round-trip"

# 6. The companion (installer/Sources/Browsers.swift) offers a browser only for features
#    that declare it in TweakFeature.browsers, and offers every browser that has one.
objcFeatures() {
    local macro
    macro="$(grep -h "^#define TWEAK_BROWSER_[A-Z]* \"$1\"" "$ROOT"/src/browsers/*/Browser.h | awk '{print $2}')"
    [ -n "$macro" ] || return 0
    grep -rh "^const TweakFeature " "$ROOT/src/features" | grep -w "$macro" | sed -E 's/^[^"]*"([^"]+)".*/\1/' | sort || true
}
while IFS=: read -r id claimed; do
    declared="$(objcFeatures "$id")"
    for f in ${claimed//,/ }; do
        grep -qx "$f" <<<"$declared" || { echo "FAIL companion says $id supports $f, but src/features/$f doesn't declare it"; exit 1; }
    done
    if [ -n "$declared" ] && [ -z "$claimed" ]; then echo "FAIL $id has features ($declared) but the companion never offers it"; exit 1; fi
done < <(awk '/ id: "/ { match($0, /id: "[^"]+"/); id = substr($0, RSTART + 5, RLENGTH - 6) }
              /features: \[("|\])/ { match($0, /features: \[[^]]*\]/); f = substr($0, RSTART + 11, RLENGTH - 12); gsub(/[" ]/, "", f); print id ":" f }' \
              "$ROOT/installer/Sources/Browsers.swift")
pass "companion's browser list matches what the features declare"
# 7. Optional: the browser classes src/ looks up by name exist in the installed Dia.
# Reads its binaries' strings only; skipped where there is no Dia (CI).
if [ -d /Applications/Dia.app ]; then
    if ! "$ROOT/scripts/check-classes.sh" /Applications/Dia.app > "$WORK/classes.txt"; then
        grep -v '^OK' "$WORK/classes.txt"; echo "FAIL classes missing in /Applications/Dia.app"; exit 1
    fi
    pass "Dia classes present ($(tail -1 "$WORK/classes.txt"))"
else
    echo "skip Dia class check (no /Applications/Dia.app)"
fi
