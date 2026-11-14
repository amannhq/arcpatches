# Changelog

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
