# Command line reference

Everything the ArcPatches app does from its window can also be done from a terminal.
This page covers the install script, the `ArcPatches` binary's flags, and every setting the patch reads.

To install with an AI coding agent instead, paste the prompt in [agent-install.md](agent-install.md).

## Install script

```bash
curl -fsSL https://raw.githubusercontent.com/amannhq/arcpatches/main/install.sh | bash
```

[`install.sh`](../install.sh) does this, and stops with an `error:` line if any step fails:

1. Checks for macOS on Apple silicon, version 14 or later.
2. Downloads `ArcPatches.zip` and `ArcPatches.zip.sha256` from the latest GitHub release and compares the checksums.
3. Unzips the app and checks its code signature with `codesign --verify --deep --strict`.
4. Quits a running ArcPatches, if there is one.
5. Installs `ArcPatches.app` to `/Applications`, or to `~/Applications` when `/Applications` isn't writable.
6. Opens ArcPatches.

Files fetched with `curl` aren't quarantined, so macOS doesn't ask you to approve the app in System Settings.
ArcPatches isn't notarized yet, because that needs a paid Apple developer account.
Read the script before you run it if you like: it's about 50 lines.

## The `ArcPatches` binary

The app's executable doubles as a command line tool.
With one of the flags below as its first argument it does that one job, prints a line, and exits without showing a window.

```bash
AP=/Applications/ArcPatches.app/Contents/MacOS/ArcPatches   # or ~/Applications/…
"$AP" --status
```

| Flag | What it does |
| --- | --- |
| `--status` | Prints the selected browser, patch mode, target path, whether the target and the stock browser are running, the browser's version, what the patched app was built from, the patch version, the state, the menu bar mode and whether the background job is installed. Changes nothing. |
| `--patch` | Patches the selected browser now. The browser must be quit. Prints `Patched: <version>`. |
| `--restore` | Puts the untouched original browser back (in-place mode only). The browser must be quit. ArcPatches then leaves it alone until you patch again. Prints `Restored: <version>`. In copy mode it does nothing, because the original was never changed. |
| `--mode inPlace\|copy` | Switches between patching the browser itself (`inPlace`, the default) and building a separate `~/Applications/Dia Arc.app` (`copy`). Restores or patches as needed. Both apps must be quit. |
| `--browser <id>` | Chooses which browser to patch: `dia` (the default) or another installed browser that at least one feature supports (today `ardia`). Prints the usage line, listing the choices, if `<id>` is missing or not offered. |
| `--background-mode on\|off` | `on` installs the background job (`~/Library/LaunchAgents/dev.amannhq.arcpatches.watch.plist`), which re-patches after browser updates with no menu bar icon, and removes the login item. `off` removes the job. |
| `--background-check` | Runs one background check: re-patches if the browser needs it and auto re-patch is on, then checks for an ArcPatches update at most once a day. The background job runs this. |
| `--update-from <zip-url> <version>` | Development only: installs a specific signed ArcPatches build. The signature is fetched from `<zip-url>.sig` and must verify. |
| `--make-icon [dir]` | Development only: writes the app icon (`.icns`) to `dir`, or the current directory. |
| `--help` | Prints the usage line. |

Errors print `error: <message>` and exit. The ones you're likely to see:

| Message | What to do |
| --- | --- |
| `Quit Dia first.` | Quit the browser (and `Dia Arc` in copy mode), then run the command again. |
| `Already patching.` | The ArcPatches window or the background job is patching. Wait a few seconds and check `--status`. |
| `macOS blocked ArcPatches from changing Dia. Allow ArcPatches in System Settings › Privacy & Security › App Management, then try again.` | Allow it there. When the command runs from a terminal, macOS may ask about the terminal app instead; patching from the ArcPatches window avoids that. |
| `Dia.app isn't an untouched Dia signed by …` | Another tool modified Dia. Restore it with that tool, or reinstall Dia from [diabrowser.com](https://www.diabrowser.com), then patch again. |
| `The original Dia backup is missing.` | Reinstall Dia, then patch again. |

### Reading `--status`

```
browser: dia  mode: inPlace  target: /Applications/Dia.app  running: false  Dia running: false
Dia: 1.57.1  Dia: 1.57.1  patch: 0.1.0-…  state: upToDate  menu bar: whenNeeded  background job: false
```

`state` is one of:

| State | Meaning |
| --- | --- |
| `upToDate` | Patched with this version of ArcPatches. Done. |
| `needsPatch("…")` | Not patched yet, or out of date. The reason says why: `Dia isn't patched`, `Dia was updated`, `New ArcPatches version`, `Original backup missing` and so on. Run `--patch`. |
| `notInstalled` | Never patched (copy mode: the copy doesn't exist yet). |
| `restored` | You restored the original. ArcPatches won't re-patch until you run `--patch`. |
| `diaMissing` | The browser isn't in `/Applications`. |

### Environment overrides

For testing only: `ARCPATCHES_DIA_PATH` points ArcPatches at a different copy of Dia (`ARCPATCHES_ARDIA_PATH` and so on for other browsers), and `ARCPATCHES_SUPPORT_DIR` moves its support folder away from `~/Library/Application Support/arcpatches`.

## Settings

The patch keeps its settings in the browser's own preferences, under keys that start with `arcpatches.`.
**Settings → ArcPatches** inside the patched browser changes all of them.
From a terminal, quit the browser first, then:

```bash
defaults write company.thebrowser.dia arcpatches.<key> -bool YES     # or NO
defaults write company.thebrowser.dia arcpatches.<key> -int 2        # numeric settings
defaults delete company.thebrowser.dia arcpatches.<key>              # back to the default
defaults read company.thebrowser.dia | grep arcpatches               # what you've changed
```

The domain is the same whether Dia is patched in place or as a copy, because both keep Dia's bundle identifier.

### Sidebar URL bar

| Key | Type | Default | Effect |
| --- | --- | --- | --- |
| `urlBarMode` | int | `2` | Where the address bar lives. `0` Dia's stock bar at the top, `1` hidden, `2` in the sidebar. ⌃⌘U switches between `0` and the last of the other two. |
| `commandBarStyle` | int | `2` | What ⌘T, ⌘L and the sidebar URL bar open. `2` ArcPatches's Arc-style command bar, `1` Dia's own editor re-anchored to the sidebar, `0` Dia's defaults. |
| `revealOnHover` | bool | `NO` | Moving the pointer to the top edge of a page shows Dia's bar. Only when `urlBarMode` isn't `0`. |
| `cmdLFocusesSidebar` | bool | `YES` | With Dia's editor as the command bar (`commandBarStyle` `1`), ⌘L opens it at the sidebar instead of the top. |
| `sidebarShowsFullURL` | bool | `NO` | Shows the full URL in the sidebar pill. Otherwise only the site's domain. |
| `sidebarShowsNavButtons` | bool | `YES` | Back, forward and reload next to the window buttons. |
| `sidebarPillButtons` | bool | `YES` | Copy-link and site-controls buttons that appear when the pointer is over the URL pill. |
| `topBarWhenSidebarHidden` | bool | `NO` | Shows Dia's bar while the sidebar is collapsed. Off is like Arc: no URL bar until the sidebar is back. |

### Sidebar top row

| Key | Type | Default | Effect |
| --- | --- | --- | --- |
| `sidebarToggleButton` | bool | `YES` | A sidebar toggle after the window buttons. |
| `topRowProfileName` | bool | `NO` | Keeps Dia's profile name in the sidebar header. Arc shows none. |
| `hideWindowButtonsInFullScreen` | bool | `YES` | In full screen the top row starts with the toggle, as in Arc. |

### Shortcuts

| Key | Type | Default | Effect |
| --- | --- | --- | --- |
| `arcShortcut.copyURL` | bool | `YES` | ⌘⇧C copies the URL without tracking parameters (`utm_*`, `fbclid`, `gclid` and others). |
| `arcShortcut.copyMarkdown` | bool | `YES` | ⌘⇧⌥C copies `[page title](URL)`. |
| `extraShortcuts` | bool | `NO` | Extra keys for tidying tabs and switching profiles. Change each key in Settings → ArcPatches → Shortcuts. |
| `profileNumberMods` | int | ⌃ | Modifiers for "switch to profile 1–9", as an `NSEvent` modifier mask: `262144` ⌃, `786432` ⌃⌥, `1310720` ⌃⌘, `0` none. Needs `extraShortcuts`. |

### Privacy

| Key | Type | Default | Effect |
| --- | --- | --- | --- |
| `hideAI` | bool | `YES` | Hides chat menus and shortcuts, Chats in the sidebar, the Chat button, "Chat with this tab" and page content extraction. |
| `blockAI` | bool | `NO` | Blocks Dia's AI endpoints and Google's Gemini API. Applies after restarting the browser. |
| `blockTelemetry` | bool | `NO` | Blocks Datadog, Sentry, Segment, LaunchDarkly events and Dia's OpenTelemetry gateway. Applies after restarting the browser. |

Host blocking is best effort. Use a firewall such as LuLu or Little Snitch if you need a guarantee.

### Performance

These apply after restarting the browser.

| Key | Type | Default | Effect |
| --- | --- | --- | --- |
| `disableOnDeviceAI` | bool | `YES` | Doesn't start Dia's local AI service process (about 40 MB). Needs `hideAI`. |
| `rendererProcessLimit` | int | `0` | Tabs share renderer processes above this number: `0` Chromium's default, or `16`, `8`, `4`. Lower uses less memory, but one crash can take several tabs with it. |
| `noBackgroundNetworking` | bool | `NO` | Stops Chromium's background updaters (components, field trials). May delay Safe Browsing list updates. |

### Internal keys

`arcpatches.newTabPalette` is registered (default `YES`) but the current build doesn't read it: `commandBarStyle` decides what ⌘T opens.
ArcPatches also writes `arcpatches.lastHiddenMode`, `arcpatches.handoffExplained`, `arcpatches.saved.*` and `arcpatches.shortcut.<action>` (a dictionary per shortcut).
Leave them alone: change shortcuts in the Settings pane.

There is no developer-tools setting. To dump the view tree while developing, see the comment at the top of [`src/core/DevDump.m`](../src/core/DevDump.m).

## The app's own settings

The ArcPatches app keeps its settings in its own domain, `dev.amannhq.arcpatches`. Change them in its window where you can.

| Key | Type | Default | Effect |
| --- | --- | --- | --- |
| `autoRepatch` | bool | `YES` | Re-patch automatically after the browser updates. |
| `autoUpdateSelf` | bool | `YES` | Install signed ArcPatches updates automatically. |
| `menuBarMode` | string | `whenNeeded` | `always`, `whenNeeded` or `never`. |
| `browser` | string | `dia` | The browser to patch. Use `--browser`. |
| `patchMode` | string | `inPlace` | `inPlace` or `copy`. Use `--mode`, which also moves the patch. |

## Uninstall

```bash
AP=/Applications/ArcPatches.app/Contents/MacOS/ArcPatches   # quit Dia first
"$AP" --restore                       # put the original Dia back
"$AP" --background-mode off           # remove the background job
rm -f ~/Library/LaunchAgents/dev.amannhq.arcpatches.plist   # the login item, if you turned it on
rm -rf /Applications/ArcPatches.app   # or ~/Applications/ArcPatches.app
```

In copy mode, delete `~/Applications/Dia Arc.app` instead of running `--restore`.
To remove everything else as well: `rm -rf ~/Library/Application\ Support/arcpatches`, `defaults delete dev.amannhq.arcpatches`, and delete the `arcpatches.*` keys from `company.thebrowser.dia` one by one with `defaults delete`.
