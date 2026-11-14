#!/bin/bash
# Installs the latest ArcPatches release:
#   curl -fsSL https://raw.githubusercontent.com/amannhq/arcpatches/main/install.sh | bash
#
# Why a script: ArcPatches isn't notarized by Apple (that needs a paid developer
# account). A browser download is quarantined, and macOS 15+ then makes you approve it
# in System Settings. Files fetched with curl aren't quarantined, so this skips that.
# You're trusting this script and the GitHub release it downloads: read it first if you like.
set -euo pipefail

REPO="amannhq/arcpatches"
BASE="https://github.com/$REPO/releases/latest/download"
APP="ArcPatches.app"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || die "ArcPatches is for macOS."
[ "$(uname -m)" = arm64 ] || die "ArcPatches needs a Mac with Apple silicon."
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 14 ] || die "ArcPatches needs macOS 14 or later (this Mac has $(sw_vers -productVersion))."

# /Applications when we can write there, else ~/Applications.
DEST="/Applications"
if [ ! -w "$DEST" ]; then DEST="$HOME/Applications"; mkdir -p "$DEST"; fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say "Downloading the latest ArcPatches…"
curl -fsSL "$BASE/ArcPatches.zip" -o "$WORK/ArcPatches.zip"
curl -fsSL "$BASE/ArcPatches.zip.sha256" -o "$WORK/ArcPatches.zip.sha256"

say "Checking the download…"
expected="$(awk '{print $1}' "$WORK/ArcPatches.zip.sha256")"
actual="$(shasum -a 256 "$WORK/ArcPatches.zip" | awk '{print $1}')"
[ -n "$expected" ] && [ "$expected" = "$actual" ] || die "checksum mismatch: the download is incomplete or was altered."

ditto -x -k "$WORK/ArcPatches.zip" "$WORK/unzipped"
[ -d "$WORK/unzipped/$APP" ] || die "the release doesn't contain $APP."
codesign --verify --deep --strict "$WORK/unzipped/$APP" 2>/dev/null || die "$APP's signature doesn't verify."

if pgrep -xq ArcPatches; then
    say "Quitting the running ArcPatches…"
    osascript -e 'tell application "ArcPatches" to quit' >/dev/null 2>&1 || true
    sleep 1
fi

say "Installing to $DEST…"
rm -rf "${DEST:?}/$APP"
ditto "$WORK/unzipped/$APP" "$DEST/$APP"

say "Done. Opening ArcPatches: quit Dia, then click Patch."
open "$DEST/$APP"
