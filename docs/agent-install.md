# Install ArcPatches with an AI agent

Copy everything between the two markers below and paste it into an AI coding agent that can run terminal commands on your Mac: Claude Code, Cursor, Codex, or similar.
The agent checks your Mac, installs ArcPatches, asks before anything that quits an app or removes something, patches Dia, and tells you what to try.

Prefer doing it yourself? See the [README](../README.md#install) or the [command line reference](cli.md).

<!-- AGENT-PROMPT-START -->
You are installing ArcPatches (https://github.com/amannhq/arcpatches) on my Mac. ArcPatches is an open-source (MIT) tool that patches my own copy of the Dia browser with Arc's sidebar URL bar, ⌘T command bar and shortcuts. It keeps an untouched backup of Dia and can restore it at any time. Work through the steps below in order, run each command yourself, and show me the important output. Be careful and conservative.

Rules for the whole task:
- Never quit, force-quit or kill Dia or any other app without asking me first and waiting for my answer. Never use `kill`, `pkill` or `killall`.
- Never use `sudo`. Never edit anything inside `/Applications/Dia.app` yourself; only the ArcPatches binary changes it.
- Ask me before removing anything. If a step fails, stop, show me the exact error, and suggest the fix from the table in step 9. Don't improvise workarounds.
- Don't install other software, and don't disable Gatekeeper or SIP.

## 1. Check prerequisites

Run these and check the results. Stop and tell me which one failed if any does.

```bash
sw_vers -productVersion          # must be 14 or later
uname -m                         # must be arm64 (Apple silicon)
test -d /Applications/Dia.app && echo "Dia found" || echo "Dia missing"
defaults read /Applications/Dia.app/Contents/Info CFBundleShortVersionString
```

- Dia must be in `/Applications`. If it's missing, tell me to install it from https://www.diabrowser.com and stop.
- Tell me the Dia version. ArcPatches is tested on Dia 1.57.x. On a much newer Dia, some features may switch themselves off; that's safe, so carry on.

## 2. Check for other Dia patchers

Two patchers on one app break each other. Check:

```bash
command -v diatweaks && echo "DiaTweaks is installed"
codesign --verify --strict /Applications/Dia.app 2>&1 && echo "Dia signature OK"
codesign -dv /Applications/Dia.app 2>&1 | grep -E "TeamIdentifier|Signature"
```

- If `diatweaks` is installed, tell me, and ask whether to run `diatweaks restore --purge -y` to remove its changes. Only run it if I say yes. If I say no, stop: ArcPatches won't patch a Dia that another tool modified.
- If Dia's signature isn't valid, or it's signed ad hoc (`Signature=adhoc`) and ArcPatches has never been installed, another tool has probably changed it. Tell me and suggest reinstalling Dia from https://www.diabrowser.com before continuing.

## 3. Install ArcPatches

```bash
curl -fsSL https://raw.githubusercontent.com/amannhq/arcpatches/main/install.sh | bash
```

The script checks the download's SHA-256 checksum and code signature, installs `ArcPatches.app` to `/Applications` (or `~/Applications` if `/Applications` isn't writable), and opens the ArcPatches window. You may read the script first at the same URL.

Then find the binary and use it for the rest of the task:

```bash
AP=/Applications/ArcPatches.app/Contents/MacOS/ArcPatches
[ -x "$AP" ] || AP="$HOME/Applications/ArcPatches.app/Contents/MacOS/ArcPatches"
"$AP" --status
```

Shell variables may not survive between your commands, so repeat the two `AP=` lines whenever you need them.

## 4. Quit Dia

Look at the first line of `--status`. It contains `running: true|false` (the app ArcPatches will replace) and ends with `Dia running: true|false`.

If either is `true`, ask me to quit Dia myself (⌘Q in Dia) and wait until I say it's done. Only if I explicitly ask you to quit it for me, run `osascript -e 'tell application "Dia" to quit'`. Never force-quit. Run `"$AP" --status` again and continue only when it shows both `running: false` and `Dia running: false`.

## 5. Patch

```bash
"$AP" --patch
"$AP" --status
```

Success is `Patched: <version>` from `--patch`, and `state: upToDate` in `--status`.
The ArcPatches window that the install script opened may already be patching: if you see `Already patching.`, wait 15 seconds and run `--status` again.

## 6. Settings (optional)

Ask me whether I want to change any of these before Dia starts, and show me the list. The defaults are good, so skipping this is fine. Every setting can also be changed later in Dia under Settings → ArcPatches.

Write settings only while Dia is quit, with `defaults write company.thebrowser.dia arcpatches.<key> -bool YES` (or `NO`) for on/off settings and `-int <n>` for numbers.

| Key | Type | Default | What it does |
| --- | --- | --- | --- |
| `urlBarMode` | int | 2 | URL bar: 0 Dia's bar at the top, 1 hidden, 2 in the sidebar like Arc |
| `commandBarStyle` | int | 2 | What ⌘T and ⌘L open: 2 ArcPatches's Arc-style command bar, 1 Dia's editor, 0 Dia's defaults |
| `revealOnHover` | bool | NO | Show Dia's top bar when the pointer reaches the top edge of a page |
| `sidebarShowsFullURL` | bool | NO | Full URL in the sidebar instead of the domain only |
| `sidebarShowsNavButtons` | bool | YES | Back, forward and reload next to the window buttons |
| `sidebarPillButtons` | bool | YES | Copy-link and site-controls buttons when hovering the URL pill |
| `topBarWhenSidebarHidden` | bool | NO | Show Dia's bar while the sidebar is collapsed |
| `cmdLFocusesSidebar` | bool | YES | With Dia's editor (`commandBarStyle` 1), ⌘L opens it at the sidebar |
| `sidebarToggleButton` | bool | YES | Sidebar toggle button after the window buttons |
| `topRowProfileName` | bool | NO | Keep Dia's profile name in the sidebar header |
| `hideWindowButtonsInFullScreen` | bool | YES | In full screen, the top row starts with the toggle, like Arc |
| `arcShortcut.copyURL` | bool | YES | ⌘⇧C copies the URL without tracking parameters |
| `arcShortcut.copyMarkdown` | bool | YES | ⌘⇧⌥C copies a Markdown link to the page |
| `extraShortcuts` | bool | NO | Extra keys: sort and group tabs by domain (⌃⌥S, ⌃⌥G), next and previous profile (⌃⌥→, ⌃⌥←) |
| `profileNumberMods` | int | 262144 | Keys for "switch to profile 1–9" (needs `extraShortcuts`): 262144 ⌃1…⌃9, 786432 ⌃⌥, 1310720 ⌃⌘, 0 none |
| `hideAI` | bool | YES | Hide Dia's AI chat entry points |
| `disableOnDeviceAI` | bool | YES | Don't start Dia's local AI process (needs `hideAI`) |
| `blockAI` | bool | NO | Block Dia's AI and Gemini hosts |
| `blockTelemetry` | bool | NO | Block telemetry hosts (Datadog, Sentry, Segment and others) |
| `noBackgroundNetworking` | bool | NO | Stop Chromium's background updaters |
| `rendererProcessLimit` | int | 0 | Share renderer processes above this many tabs: 0 default, or 16, 8, 4 |

Example: `defaults write company.thebrowser.dia arcpatches.blockTelemetry -bool YES`.
To undo one: `defaults delete company.thebrowser.dia arcpatches.<key>`.

## 7. Reopen Dia and try it

Ask me whether to open Dia now. If I agree, run `open -a Dia`.

Tell me:
- If macOS asks about "Dia Safe Storage", choose **Always Allow**. It asks once, because the patched app is signed on this Mac rather than by The Browser Company.
- What to try:
  - **⌘T** opens the Arc-style command bar: search open tabs, history and bookmarks, or type a site.
  - **⌘L**, or a click on the URL at the top of the sidebar, edits the address.
  - **Hover the URL pill** in the sidebar to show the copy-link and site-controls buttons.
  - **⌘⇧C** copies a clean link; **⌘S** toggles the sidebar.
  - **Full screen**: move the pointer to the top edge of the page to bring the toolbar back.
- Everything can be switched off in Dia's Settings → ArcPatches.
- ArcPatches re-patches Dia after each Dia update, from its menu bar app or background job.

## 8. Undo

Tell me how to undo, but don't run any of it unless I ask.

Restore the original Dia (Dia must be quit):

```bash
"$AP" --restore
```

Uninstall ArcPatches completely (Dia must be quit):

```bash
"$AP" --restore
"$AP" --background-mode off
rm -f ~/Library/LaunchAgents/dev.amannhq.arcpatches.plist
rm -rf /Applications/ArcPatches.app ~/Applications/ArcPatches.app
```

Optional cleanup of leftovers: `~/Library/Application Support/arcpatches` (the backup of the original Dia lives here, so remove it only after `--restore` succeeded), `defaults delete dev.amannhq.arcpatches`, and the `arcpatches.*` keys in `company.thebrowser.dia`.

## 9. If something fails

| Message | What to do |
| --- | --- |
| `Quit Dia first.` | Go back to step 4. |
| `Already patching.` | Wait 15 seconds, then `"$AP" --status`. |
| `macOS blocked ArcPatches from changing Dia…` | Ask me to allow ArcPatches (or this terminal app) in System Settings → Privacy & Security → App Management. Or ask me to click **Patch** in the ArcPatches window instead, then check `--status`. |
| `… isn't an untouched Dia signed by …` | Another tool changed Dia. Ask me to reinstall Dia from https://www.diabrowser.com, then patch again. |
| `The original Dia backup is missing.` | Same: reinstall Dia, then patch again. |
| `checksum mismatch` or `signature doesn't verify` from the install script | Stop. Don't work around it. Tell me to try again later or report it at https://github.com/amannhq/arcpatches/issues. |

Finish with a short summary: Dia version, ArcPatches status line, settings you changed, and the undo command.
<!-- AGENT-PROMPT-END -->

## What the agent will and won't do

- It asks before quitting Dia, removing DiaTweaks, opening Dia, or deleting anything.
- It never uses `sudo`, never force-quits, and never edits Dia's files directly.
- Everything it runs is listed above and in the [command line reference](cli.md).
