# Browser support

ArcPatches injects one dylib into a Chromium browser's app bundle. A feature can only
run in a browser that exposes the native classes, methods or switches it hooks, so
support is decided per feature and per browser. Each feature declares its browsers in
`src/features/<name>/` (`TweakFeature.browsers`), and `tests/run.sh` checks that the
companion app never offers more than that.

Original Arc (`company.thebrowser.Browser`) is deliberately not supported because it is
discontinued.

## Matrix

| Feature | Dia 1.57 | Ardia 0.2 | Chrome 157 |
| --- | --- | --- | --- |
| `sidebar`: URL pill, top bar hiding, nav buttons | yes | no (1) | no (5) |
| `commandbar`: ⌘T / ⌘L command bar, new-tab palette | yes | no (2) | no (5)(6) |
| `privacy`: hide AI, block AI and telemetry hosts | yes | no (3) | no (5)(7) |
| `performance`: Chromium switches | yes | **yes** (4) | no (7) |
| `performance`: on-device AI off | yes | not applicable (4) | no (5) |
| `shortcuts`: tab tidying, profile switching | yes | no (2) | no (6) |
| `tabs`: sort and group by domain | yes | no (2) | no (5) |
| `preferences`: ArcPatches pane in Settings | yes | no (1) | no (5) |

The companion's browser picker lists an installed browser only if at least one feature
supports it. Today that means Dia and Ardia. Dia remains the default.

## Why a cell is "no"

1. **Ardia's UI is React Native.** The sidebar, toolbar and settings are JavaScript
   views rendered by React Native macOS. The native side (`ArdiaCore`, `ArdiaShell`)
   only has generic modules such as `CefWebView`, `ChromeUIModule` and
   `WindowManager`. None of Dia's `TabSidebar`, `NavigationBar` or `Preferences`
   classes exist, and hooking RN views by class name would break on every release.
   Ardia already ships an Arc-style sidebar of its own.
2. **These features need Dia-only native classes or scripting.**
   - `commandbar` uses Dia's `DiaAppleScriptTab` scripting bridge, Dia's window class
     and Dia's `User Data` folder.
   - `shortcuts` drives Dia's AppleScript `profiles`.
   - `tabs` uses ADK's `ArcBrowser` and `ArcTabGroupProperties`.

   None of these appear in Ardia's binary. Ardia has its own command bar
   (`InlineCompletionModule`).
3. **Privacy targets Dia's services.**
   - The AI hosts are `*.diabrowser.engineering`.
   - The telemetry hosts (Datadog, Sentry, Segment, LaunchDarkly) appear nowhere in
     Ardia's binary or `main.jsbundle`.
   - The AI surfaces it hides are Dia's classes.

   Blocking these hosts in Ardia would do nothing. Saying it does would be dishonest.
4. **Ardia: switches work, through a different hook.** Dia's switches go through
   `ArcBrowserApplicationConfiguration.argv`, which exists only in Dia. Ardia's CEF
   launcher instead reads `ARDIA_CHROMIUM_SWITCHES` with `getenv()`.
   - The launcher splits the value on `" --"` and appends each switch to Chromium's
     command line.
   - It does this only when the running app's signature has no Team ID, which is true
     of an ad hoc re-signed copy like Ardia Arc.
   - The dylib's constructor appends `--disable-background-networking` and
     `--renderer-process-limit=N` to that variable before `main()`, keeping any value
     the user already set.

   Ardia has no `ArcAIService`, so there is no on-device AI to stop.
5. **Chrome's UI is C++ (Chromium Views).** It has no Objective-C or Swift view
   classes to hook. The only Objective-C is plumbing (`AppController`,
   `NativeWidgetMacNSWindow`). Chrome's code also lives in
   `Google Chrome Framework.framework`, which the stub executable `dlopen`s after the
   dylib's constructor has already run.
6. **Chrome's AppleScript differs from Dia's.** It has `appleScriptWindows`, but no
   profiles and none of Dia's tab properties. The command bar and shortcuts would need
   a Chrome adapter, which doesn't exist yet.
7. **Chrome has no switch hook.** `ChromeMain` takes `main()`'s `argv` unchanged, and
   official builds read no environment or config file for switches. The Chromium
   `argv` that `--host-resolver-rules` and the performance switches need is therefore
   out of reach.

Chrome would also need two installer changes before it could be patched:

- **Universal executable.** Its executable is universal (x86_64 + arm64), and the
  patcher only edits thin arm64 executables.
- **Keystone updates.** Chrome is updated by Keystone, which would replace a patched
  copy in place.

## Ardia caveats (shown in the picker)

- **Settings.** Nothing changes until you turn a switch on. There is no ArcPatches
  pane in Ardia, so set the switches from Terminal:
  `defaults write com.ardia.browser arcpatches.noBackgroundNetworking -bool true`
  or `defaults write com.ardia.browser arcpatches.rendererProcessLimit -int 4`.
  Then relaunch Ardia Arc.
- **Keychain.** The same no-Team-ID check that enables the switches also makes Ardia
  add `--use-mock-keychain`. Ardia Arc therefore cannot read cookies or passwords the
  original Ardia encrypted with the real keychain. Expect to sign in to sites again,
  and keep saved passwords in the original Ardia. This happens to any re-signed Ardia,
  whether or not a switch is on.
- **Dropped entitlements.** Re-signing drops Ardia's restricted entitlements (keychain
  groups, Apple Events automation). Importing from other browsers through Apple Events
  may stop working in Ardia Arc.

## Where things live

| | Dia | Ardia | Chrome |
| --- | --- | --- | --- |
| Descriptor | `src/browsers/dia/` | `src/browsers/ardia/` | `src/browsers/chrome/` |
| Bundle id | `company.thebrowser.dia` | `com.ardia.browser` | `com.google.Chrome` |
| Patched name | Dia Arc | Ardia Arc | (not offered) |
| Support folder | `~/Library/Application Support/arcpatches/` | `…/arcpatches/ardia/` | `…/arcpatches/chrome/` |
| Backup (in place) | `Dia-original.app` | `Ardia-original.app` | — |
| Pristine signer (Team ID) | S6N382Y83G | U5L5T3NGVV | EQHXZ8M8AV |

The dylib finds the browser by bundle id (`src/core/Browsers.m`). It installs only the
features that list that browser. If no feature does, it installs nothing.

The companion's descriptors are in `installer/Sources/Browsers.swift`. Use
`ArcPatches --browser <id>` to pick a browser from the command line.
