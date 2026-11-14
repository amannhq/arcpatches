<div align="center">

# ArcPatches

**Arc's sidebar and workflow, patched into the browser you use now.**

[![CI](https://github.com/amannhq/arcpatches/actions/workflows/ci.yml/badge.svg)](https://github.com/amannhq/arcpatches/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/amannhq/arcpatches?include_prereleases)](https://github.com/amannhq/arcpatches/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
![macOS 14+ · Apple silicon](https://img.shields.io/badge/macOS-14%2B%20·%20Apple%20silicon-lightgrey)

</div>

Arc is going away. Its successor, Dia, is fast and polished but leaves out much of what made Arc Arc.
ArcPatches brings those parts back: the URL bar in the sidebar, a full-window page, the `⌘T` command bar and Arc's shortcuts.
It does this by patching your own copy of the browser on your Mac. Nothing of the browser is downloaded or redistributed.

> [!WARNING]
> ArcPatches is unofficial and is not affiliated with or endorsed by The Browser Company.
> Patching an app may go against its terms of use. Read [Security and trade-offs](#security-and-trade-offs) before installing.

## Features

| | |
| --- | --- |
| **Sidebar URL bar** | The current site sits at the top of the sidebar, with back, forward and reload beside the window buttons. Hovering shows copy-link and site-controls buttons. |
| **Full-window pages** | The top toolbar is hidden, so pages use the whole window. Hover the top edge to bring the toolbar back. |
| **Command bar** | `⌘T`, `⌘L` or a click on the URL opens it. It searches open tabs, history and bookmarks, runs browser commands, opens `chrome://` pages, and completes sites as you type. |
| **Arc shortcuts** | `⌘S` toggles the sidebar, `⌘⇧C` copies a clean URL, `⌘⇧⌥C` copies a Markdown link. Each one can be turned off. |
| **AI out of the way** | Hides chat entry points and stops the local AI agent and the on-device model process. Can optionally block AI and telemetry hosts. |
| **Stays patched** | The ArcPatches menu bar app patches the browser again after each update and restores the original in one click. |

Every feature can be switched off in **Settings → ArcPatches** inside the patched browser.

## Supported browsers

| Browser | Status |
| --- | --- |
| **Dia** (macOS) | ✅ Supported. Tested on 1.57.x. |
| Ardia, Chrome | 🧪 Investigating. See [docs/browsers.md](docs/browsers.md) for what can work and why. |
| Arc | ❌ Not a target. Arc already is Arc, and The Browser Company is retiring it. |

## Install

**Requirements:** a Mac with Apple silicon, macOS 14 or later, and the browser in `/Applications`.

1. Download `ArcPatches.zip` from the [latest release](https://github.com/amannhq/arcpatches/releases/latest) and move `ArcPatches.app` to Applications.
2. Quit the browser, open ArcPatches, and click **Patch**. On the first launch, right-click the app and choose **Open**, because releases aren't notarized yet.
3. If macOS asks about "Dia Safe Storage", choose **Always Allow**.

To leave the original app untouched, untick **Patch Dia directly**.
ArcPatches then builds a separate `~/Applications/Dia Arc.app`.
Use one or the other, not both, because they share a profile.

**Uninstall:** click **Restore Original Dia** in ArcPatches, then delete `ArcPatches.app`.

### Build from source

```bash
xcode-select --install
git clone https://github.com/amannhq/arcpatches.git
cd arcpatches
./tests/run.sh                          # tests that need no browser
./companion/build.sh --launch           # build and open the ArcPatches app
```

## How it works

```
/Applications/Dia.app ──clone──▶ pristine backup (APFS clone, no extra space)
          │
          └──▶ + arcpatches.dylib + weak load command ──re-sign──▶ patched app
                         │
                         └── at launch: hooks a few private AppKit views
                             (sidebar header, toolbar, command bar) and
                             adds the Arc-style UI next to them
```

- **Small surface.** The dylib changes the browser's own views at runtime. It doesn't patch the binary's code.
- **Fails safe.** If a browser update renames a class a feature relies on, that feature switches itself off and the health list in the app tells you which one.
- **Updates still work.** The browser's own updater stays on, and ArcPatches patches the new version after it installs.
- **Signed updates for ArcPatches.** Releases are verified with an ed25519 key held only in this repository's CI secrets.

## Security and trade-offs

- The patched app is signed ad hoc on your Mac, not by The Browser Company. Keychain items such as "Dia Safe Storage" ask once for access.
- The hardened runtime stays on. Only library validation is relaxed so that `arcpatches.dylib` can load. `DYLD_INSERT_LIBRARIES` is still blocked.
- Passkeys from Apple Passwords only work in the vendor-signed app. Use a password-manager extension, a phone (QR code), or the menu item that opens the current tabs in the original app.
- Host blocking is best effort. Use a firewall such as LuLu or Little Snitch if you need a guarantee.

Found a vulnerability? Please follow [SECURITY.md](SECURITY.md) and don't open a public issue.

## Contributing

Contributions are welcome, from bug reports to new patches.
Start with [CONTRIBUTING.md](CONTRIBUTING.md). It covers the project layout, how to find the browser view to hook, testing, and the pull request checklist.
Everyone taking part is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE). Dia and Arc are trademarks of The Browser Company. They're used here only to say which browser ArcPatches works with.
