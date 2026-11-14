#!/bin/bash
# Dev tool: downloads 64-px favicons of the public sites in the README screenshots into
# build/shot-icons/<domain>.png (git-ignored). shots.m falls back to letter tiles for any
# icon that's missing, so a failed download only makes that one icon plainer.
#   tools/screenshots/fetch-icons.sh   (run from the repo root)
set -uo pipefail

DOMAINS=(
    github.com youtube.com mail.google.com figma.com notion.so slack.com linear.app wikipedia.org
    nextjs.org developer.apple.com news.ycombinator.com
    1password.com ublockorigin.com grammarly.com react.dev
)

cd "$(dirname "$0")/../.."
mkdir -p build/shot-icons
for d in "${DOMAINS[@]}"; do
    if curl -fsSL --max-time 15 -o "build/shot-icons/$d.png.part" "https://www.google.com/s2/favicons?domain=$d&sz=64"; then
        mv "build/shot-icons/$d.png.part" "build/shot-icons/$d.png"
        echo "ok   $d"
    else
        rm -f "build/shot-icons/$d.png.part"
        echo "skip $d" >&2
    fi
done
