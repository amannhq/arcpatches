# ArcPatches: notes for Claude

ArcPatches has two parts:
- An Objective-C dylib (`src/`) injected into Chromium browsers (Dia today).
- A Swift menu-bar app (`installer/`) that clones the browser, adds a weak load command and re-signs the clone.

Read `README.md` first. The layout is `src/core`, `src/browsers/<id>`, `src/features/<name>` and `installer/`.

## Hard rules

- Never launch, quit or modify `/Applications/Dia.app`, any other browser, or anything in `~/Applications`. Don't run `open` on an app. Reading binaries with `strings`, `otool` or `PlistBuddy -c Print` is fine.
- Never run `./build.sh`. Never run `./installer/build.sh` without `--no-install`. Never run `tools/probe-*` or `tools/selftest*`, because they need a live browser.
- `tools/screenshots/shots*.m`, `frame.swift` (with `frame-settings.swift` and `backdrop.swift`) and `fetch-icons.sh` are safe to build and run: they render ArcPatches' own views offscreen with demo data and need no browser (commands in `shots.m`'s header; output goes to `docs/screenshots/`, and the website's per-setting stills, APNG demos and `manifest.json` to `docs/screenshots/settings/`). Run `fetch-icons.sh` first: it downloads public sites' favicons into `build/shot-icons/` (git-ignored, never committed), and missing icons fall back to letter tiles. Don't run `tools/screenshots/companion.swift`: it can write a demo health report into the real Application Support folder.
- Verification means compiling, running `./tests/run.sh`, and static checks (`scripts/check-classes.sh`). List anything only a running browser can confirm as "needs live verification".
- Browser class names live only in `src/browsers/<id>/Browser.m`. Use the `TweakHook`, `TweakFindClass` and `TweakSettings` helpers, and fail soft when a class is missing.
- No new dependencies. Keep files under about 250 lines. Match the existing style.
- Don't copy code from other Dia/Arc tweak projects (GPL or unlicensed).
- Use conventional commits. Never push. Pushing branches or tags is left to a human.

## Skills (`.claude/skills/`)

- `arcpatches-build-test`: safe build and test commands, and what never to run.
- `dia-class-check`: `scripts/check-classes.sh <app>`, which checks the classes `src/` relies on against a browser's binaries.
- `arcpatches-new-feature`: checklist for a new `src/features/<name>/`.
- `arcpatches-release`: `VERSION`, `CHANGELOG.md`, tags, the `ARCPATCHES_UPDATE_PRIVATE_KEY` secret, and why self-update needs a public repo.
