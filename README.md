# ArcPatches

Arc's look and workflow, patched into Chromium browsers on macOS. Dia is supported today, and more browsers are planned.

Apple silicon · macOS 14+ · unofficial and not affiliated with The Browser Company.

## What you get

**Sidebar like Arc**
- URL pill at the top of the sidebar, with back, forward and reload next to the window buttons
- No top toolbar: pages fill the window, and you can show the toolbar by hovering the top edge
- `⌃⌘U` switches between the browser's own toolbar and the sidebar URL bar

**Command bar**
- `⌘T`, `⌘L` or a click on the URL pill opens it
- Searches open tabs, history and bookmarks, runs browser commands and opens `chrome://` pages
- Completes sites inline (`git` → `github.com`) and only opens a tab when you pick something

**Quieter browser**
- Hides AI entry points (chat buttons, "Chat with this tab", page extraction)
- Stops the local AI agent and the on-device model process
- Optional: block AI and telemetry hosts, limit background networking

**ArcPatches app**
- Patches the browser in one click, and patches it again after each browser update
- Restores the original browser in one click
- Health list shows which features still work on the installed browser version
- Updates itself from signed releases

## Install

1. Download `ArcPatches.zip` from [Releases](https://github.com/amannhq/arcpatches/releases/latest), unzip it, and move `ArcPatches.app` to Applications.
2. Quit Dia, open ArcPatches (right-click → Open the first time), and click **Patch**.

To leave `/Applications/Dia.app` untouched, untick **Patch Dia directly**. ArcPatches then builds a separate `~/Applications/Dia Arc.app`. Use it instead of Dia, not alongside it, because both share one profile.

### Build from source

```bash
xcode-select --install
git clone https://github.com/amannhq/arcpatches.git && cd arcpatches
./installer/build.sh --launch   # the ArcPatches app
./build.sh --launch             # or just the patched browser, no app
./tests/run.sh                  # tests that don't need a browser
```

## How it works

1. ArcPatches keeps a pristine APFS clone of the browser in `~/Library/Application Support/arcpatches/`.
2. It copies `arcpatches.dylib` into the app and adds a weak load command to the executable.
3. It re-signs the app ad hoc with the hardened runtime. Only library validation is relaxed, and `DYLD_INSERT_LIBRARIES` stays blocked.
4. At runtime the dylib hooks a handful of the browser's private AppKit classes. If an update renames one, only that feature switches off.
5. Browser updates still install through the browser's own updater, and ArcPatches patches the new version.

Notes:
- **Keychain prompt ("Dia Safe Storage")**: allow it. The patched app is signed by your Mac, not by the browser's vendor.
- **Passkeys from Apple Passwords**: these only work in the vendor-signed app. Use the menu item that opens the current tabs in the original browser, a phone (QR code), or a password-manager extension.
- **Risk**: modifying the browser may go against its terms of use. Use at your own risk.

## Project layout

| Path | Contents |
| --- | --- |
| `src/core/` | The injected dylib's browser-agnostic runtime: entry point, feature registry, hook helpers, settings, health, passkey handoff |
| `src/browsers/dia/` | The Dia descriptor: bundle id, app path, profile folder, and the names of Dia's classes the features hook |
| `src/features/` | One folder per feature (`sidebar`, `commandbar`, `privacy`, `performance`, `shortcuts`, `tabs`, `preferences`), each declaring the browsers it supports |
| `installer/` | The ArcPatches menu bar app: patch engine, UI, background job, self-updater |
| `tools/` | `insert-dylib`, release signing, and dev probes / self-tests |
| `tests/` | Tests that run without a browser |
| `.github/` | CI, releases, issue and PR templates |

## Releasing

Bump `VERSION`, add a `CHANGELOG.md` section, commit, then `git tag vX.Y.Z && git push --tags`. CI builds, signs and publishes.

To set up signing once, run `./scripts/make-update-key.sh`, commit `installer/update-public-key.txt`, and store the private key with the `gh secret set` command that it prints.

## License

[MIT](LICENSE). Dia and Arc are trademarks of The Browser Company.
