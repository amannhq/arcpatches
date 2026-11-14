---
name: arcpatches-build-test
description: How to compile and test ArcPatches (the injected dylib in src/ and the installer app in installer/) without touching the user's browsers. Use before claiming any change works, when a build or tests/run.sh fails, or when deciding which build command is safe to run.
---

# Build and test ArcPatches safely

Verification here means compile, run `./tests/run.sh`, and do static checks. A live browser is never part of an agent's verification loop.

## Safe commands (run from the repo root)

1. **Full test suite.** This needs no browser and finishes in about a minute:
   ```bash
   ./tests/run.sh
   ```
   It covers these steps:
   - Compiles every `src/**/*.m` with `-Wall -Werror`, so a warning counts as a failure.
   - Compiles the Swift installer.
   - Exercises `tools/insert-dylib.c` on a throwaway binary.
   - Signs and verifies an update, then checks that a tampered file is rejected.
   - Checks that no Dia assets are in the repo.
   - Checks the browser registry (`tests/browsers.m`) and that the companion's per-browser feature lists match what each feature declares.
   - Checks that an interrupted app swap is recovered by `ArcPatches --status`, using temp paths through `ARCPATCHES_DIA_PATH` and `ARCPATCHES_SUPPORT_DIR`.
   - Runs `tests/cleanurl.m` (the copy shortcuts' URL cleaning and Markdown links).
   - Syntax-checks every `tools/**/*.m`, so the dev tools keep compiling.
   - If `/Applications/Dia.app` exists, runs `scripts/check-classes.sh` against it. This only reads the binaries' strings. See the `dia-class-check` skill.
2. **Installer bundle, without installing it:**
   ```bash
   ./installer/build.sh --no-install   # -> build/ArcPatches.app (CI does the same)
   ```
3. **Quick dylib-only compile**, the same flags tests/run.sh uses:
   ```bash
   clang -dynamiclib -arch arm64 -fobjc-arc -O2 -Wall -Werror -Wno-unused-function \
     -framework AppKit -framework QuartzCore -lsqlite3 -DARCPATCHES_VERSION='"dev"' \
     -I src/core -I src/browsers/dia -o build/arcpatches.dylib $(find src -name '*.m' | sort)
   ```
   The build scripts pick up new `.m` files automatically. A new header directory needs a matching `-I` in all three places: `build.sh`, `installer/build.sh` and `tests/run.sh`.

## Never run these (they modify or launch the user's apps)

| Command | Why it is off-limits |
| --- | --- |
| `./build.sh` (with or without `--launch`) | Deletes and rewrites `~/Applications/Dia Arc.app`, re-signs it, and re-registers it with LaunchServices. `--launch` also opens it. |
| `./installer/build.sh` without `--no-install`, or with `--launch` | Kills the running `~/Applications/ArcPatches.app`, replaces it, and can open it. |
| `open` on any `.app`, or `pkill`/`killall` on a browser | Launches or quits the user's browser. |
| Anything that writes under `/Applications/Dia.app`, `~/Applications` or a browser profile | The user's real browser and data. Reading with `strings`, `otool` or `PlistBuddy -c Print` is fine. |
| `tools/probe-*.m`, `tools/selftest*.m`, `tools/repro-gap.m`, `tools/inspect.m` | Dev probes injected into a running browser, so they need a live, patched Dia. (`tests/run.sh` only syntax-checks them.) |
| `tools/screenshots/companion.swift` | Needs no browser, but reads this Mac's real ArcPatches status and can write a demo `health.json` into the real `~/Library/Application Support/arcpatches`. |
| `ArcPatches --uninstall`, `--background-mode`, `--background-check`, `--patch`, `--restore` | Change the user's browsers, LaunchAgents or login item. `--status` with the `ARCPATCHES_*` env vars pointing at temp dirs is fine. |
| `git push`, or pushing tags | A human pushes. |

The Dia on this machine may already be patched by another tool, so it is not a valid live test target even for a human. Static checks against its binary are still valid.

`tools/screenshots/shots.m` and `frame.swift` are safe: they render ArcPatches' own views offscreen with demo data (compile line in `shots.m`'s header).

## When something fails

- **`-Werror` failures:** fix the warning. Don't drop the flag.
- **Swift build failures:** all of `installer/Sources/*.swift` compiles as one module (`ArcPatches`, macOS 14 target).
- **A class goes MISSING in the class check:** Dia renamed it. Update `src/browsers/dia/Browser.m` after checking the new name with `strings -a`. Don't allowlist it.

## Reporting

List exactly what you ran and its output summary. Anything that can only be confirmed in a running browser goes in a separate "needs live verification" list, so it is never presented as tested: hooks firing, view placement, a selector's runtime signature, and similar.
