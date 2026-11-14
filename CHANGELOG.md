# Changelog

## 0.2.0

**Arc's sidebar, closer to Arc**
- Downloads move to the bottom-left corner of the sidebar, as in Arc, instead of sitting on top of the reload button.
- In a pinned tab that has moved on from its home page, ⌘L, Copy Link, dragging the URL and Site Controls use the page you're on, not the pinned page.
- Full screen works as in Arc: the window buttons stay out of the sidebar and slide down in a title strip from the top edge. Minimize is disabled in full screen.
- The toggle and back/forward/reload sit on one line and share the URL pill's edges.
- Right-click the URL pill for Copy Link, Copy as Markdown Link and Site Controls, or drag it to drop the link anywhere.
- ⌘-click or middle-click reload to duplicate the tab.
- Copy Link, ⌘⇧C and ⌘⇧⌥C all copy a clean URL (tracking parameters removed) and confirm with "Copied" in the pill.
- The site controls popover gets pressed states and Arc's spacing and type.

**Quieter and safer**
- Timers pause while Dia is in the background, and hidden windows are skipped.
- The developer view dump is off unless you turn it on.
- Interrupted patches recover automatically, so Dia is never left missing.
- New: Uninstall ArcPatches… in the menu, or `ArcPatches --uninstall`.

**Install and docs**
- Install in one line: `curl -fsSL https://amannhq.github.io/arcpatches/install.sh | bash`. It checks the download before installing and needs no Gatekeeper approval.
- A prompt for installing with an AI agent (docs/agent-install.md) and a full command-line and settings reference (docs/cli.md).
- New site at https://amannhq.github.io/arcpatches/ with every setting and its before/after.

## 0.1.0

The first public release. ArcPatches patches your own copy of Dia so it looks and works like Arc.

**Sidebar like Arc**
- A sidebar toggle and back, forward and reload buttons in the sidebar's top row, with Arc's hover, pressed and disabled states. Reload turns as you click it and shows stop while the page loads.
- A URL pill at the top of the sidebar. It shows the host, and on hover it shows copy-link and site-controls buttons. With no page open it shows "Search or Enter URL...".
- A site-controls popover: share, copy link and site info, your extensions, per-site settings, and a security chip.
- Full screen as in Arc: the window buttons stay out of the sidebar and slide down in a title strip when you move the pointer to the top edge. Minimize is disabled in full screen.
- Dia's profile name is hidden from the top row, as in Arc.

**Command bar**
- ⌘T opens an Arc-style palette centred over the page. It searches open tabs ("Switch to Tab"), history and bookmarks, and runs commands.
- ⌘L, or a click on the pill, drops the editor down from the pill with suggestions shown before you type.

**Shortcuts**
- ⌘⇧C copies the URL without tracking parameters. ⌘⇧⌥C copies it as a Markdown link.

**Quieter Dia**
- Hides AI entry points and stops the local AI agent and the on-device model. Can optionally block AI and telemetry hosts.

**The ArcPatches app**
- Patches Dia in place, keeping its name and profile, and patches it again after each Dia update. It can restore the original in one click.
- Settings for every feature live in Dia → Settings → ArcPatches.

Requires Apple silicon, macOS 14 or later, and Dia 1.57.
