#!/bin/bash
# Checks that the browser classes ArcPatches looks up by name still exist in a given
# browser build, by reading the strings of its binaries. Read-only: nothing is
# launched, copied or modified.
#
#   scripts/check-classes.sh /Applications/Dia.app
#
# Checked against every Mach-O file under Contents/MacOS and Contents/Frameworks:
#  - the class constants of the descriptor whose bundle id matches the app
#    (src/browsers/<id>/Browser.m); identity constants (bundle id, paths) are skipped
#  - every "Module.Class" or "_Tt..." string literal elsewhere in src/ (outside src/browsers/)
#
# Exit status: 0 all found, 1 something is missing, 2 usage or setup error.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-}"
APP="${APP%/}"
if [ -z "$APP" ] || [ ! -f "$APP/Contents/Info.plist" ]; then
    echo "usage: $0 <browser.app>" >&2
    exit 2
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
DESCRIPTOR=""
for f in "$ROOT"/src/browsers/*/Browser.m; do
    [ -f "$f" ] && grep -qF "@\"$BUNDLE_ID\"" "$f" && DESCRIPTOR="$f"
done
if [ -z "$DESCRIPTOR" ]; then
    echo "No descriptor in src/browsers/ has bundle id $BUNDLE_ID" >&2
    exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The haystack: strings of every Mach-O binary in the app (main executable, frameworks,
# dylibs, helpers). find -type f skips the frameworks' Versions/Current symlinks.
find "$APP/Contents/MacOS" "$APP/Contents/Frameworks" -type f -print0 2>/dev/null \
    | xargs -0 file -N -F $'\t' --mime-type \
    | awk -F '\t' '$2 ~ /x-mach-binary/ && $1 !~ / \(for architecture [^)]*\):?$/ { print $1 }' \
    | sort -u > "$WORK/binaries"
if [ ! -s "$WORK/binaries" ]; then
    echo "No Mach-O binaries found in $APP" >&2
    exit 2
fi
while IFS= read -r bin; do strings -a "$bin"; done < "$WORK/binaries" | sort -u > "$WORK/strings"
# Mangled Swift class names (_TtC<len>Module<len>Class...), one per line.
grep -oE '_Tt[A-Za-z0-9_]+' "$WORK/strings" | sort -u > "$WORK/mangled" || true

MISSING=0
CHECKED=0
report() {   # status label value
    CHECKED=$((CHECKED + 1))
    [ "$1" = OK ] || MISSING=$((MISSING + 1))
    printf '%-8s %-40s %s\n' "$1" "$2" "$3"
}
# Escapes a literal for grep -E.
re() { printf '%s' "$1" | sed -E 's/[][\.*^$+?(){}|/]/\\&/g'; }

# "Module.Class" / "Module.Outer.Inner" -> _TtC<len>Module<len>Class / _TtCC...
mangle() {
    local IFS=. parts=() out="_Tt" p
    read -r -a parts <<< "$1"
    for ((i = 1; i < ${#parts[@]}; i++)); do out="${out}C"; done
    for p in "${parts[@]}"; do out="${out}${#p}${p}"; done
    printf '%s' "$out"
}

# One exact class: "Module.Class" (Swift, also matched by its mangled name) or a plain
# Objective-C / @objc name.
has_class() {
    case "$1" in
        *.*) grep -qFx "$(mangle "$1")" "$WORK/mangled" ;;   # what NSClassFromString resolves
        *) grep -qFx "$1" "$WORK/strings" ;;
    esac
}
# Any class in a module ("Personalization." -> _TtC15Personalization..., _TtCC...).
has_module() {
    local m="${1%.}"
    grep -qE "^_TtC+${#m}$(re "$m")" "$WORK/mangled"
}
# A class whose name starts with prefix and ends with suffix, as TweakFindClass matches.
has_prefixed() {
    grep -qE "^$(re "$1").*$(re "$2")\$" "$WORK/mangled" "$WORK/strings"
}
# A name used as a substring of class names (matched with containsString: at runtime).
has_substring() { grep -qF "$1" "$WORK/strings"; }

echo "Checking $(wc -l < "$WORK/binaries" | tr -d ' ') binaries in $APP ($BUNDLE_ID)"
echo "Descriptor: ${DESCRIPTOR#"$ROOT"/}"

# 1. Descriptor constants: NSString *const kXxx = @"value";
sed -nE 's/^NSString \*const (k[A-Za-z0-9_]+) = @"([^"]*)";.*/\1 \2/p' "$DESCRIPTOR" > "$WORK/constants"
if [ ! -s "$WORK/constants" ]; then
    echo "No 'NSString *const kXxx = @\"...\";' constants parsed from $DESCRIPTOR (format changed?)" >&2
    exit 2
fi
value_of() { awk -v k="$1" '$1 == k { print $2 }' "$WORK/constants"; }
while read -r name value; do
    case "$name" in
        *BrowserID|*BundleID|*DisplayName|*AppPath|*ProfileFolder|*Key) continue ;;   # identity, shortcut letters, KVC keys
        *Suffix) [ -n "$(value_of "${name%Suffix}Prefix")" ] && continue ;;   # checked with its prefix
    esac
    case "$value" in *://*) continue ;; esac   # URLs (e.g. chrome:// pages) aren't classes
    status=MISSING
    case "$name" in
        *Prefix)
            suffix="$(value_of "${name%Prefix}Suffix")"
            if [ -n "$suffix" ]; then
                has_prefixed "$value" "$suffix" && status=OK
                value="$value*$suffix"
            elif [ "${value%.}" != "$value" ]; then
                has_module "$value" && status=OK
            else
                has_prefixed "$value" "" && status=OK
            fi ;;
        *Module|*Name) has_substring "$value" && status=OK ;;
        *Suffix) has_substring "$value" && status=OK ;;   # a suffix without a prefix
        *) has_class "$value" && status=OK ;;
    esac
    report "$status" "$name" "$value"
done < "$WORK/constants"

# 2. Literal class names elsewhere in src/ (features and core should use the descriptor,
# but anything that slipped through is checked too).
find "$ROOT/src" -path "$ROOT/src/browsers" -prune -o \( -name '*.m' -o -name '*.h' \) -print0 \
    | xargs -0 grep -hoE '@"([A-Za-z_][A-Za-z0-9_]*(\.[A-Z][A-Za-z0-9_]*)+|_Tt[A-Za-z0-9_]+)"' 2>/dev/null \
    | sed -E 's/^@"(.*)"$/\1/' | sort -u > "$WORK/literals" || true
while IFS= read -r value; do
    [ -n "$value" ] || continue
    status=MISSING
    case "$value" in
        _Tt*) has_prefixed "$value" "" && status=OK ;;
        *) has_class "$value" && status=OK ;;
    esac
    report "$status" "(literal in src/)" "$value"
done < "$WORK/literals"

echo "$CHECKED checked, $MISSING missing"
[ "$MISSING" -eq 0 ]
