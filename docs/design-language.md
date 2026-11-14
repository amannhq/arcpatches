# Design language

ArcPatches adds UI to someone else's browser. It should look as if Arc's designers had built it: quiet, precise and native.
This page describes that language. [`src/core/ArcStyle.h`](../src/core/ArcStyle.h) holds the values. Every view uses those tokens, never literal numbers.

The sizes come from measuring Arc 1.x on macOS. Everything is drawn with Apple's system fonts and SF Symbols. **No Arc artwork, icons or images are used, copied or traced.** The goal is the same feel, not the same pixels.

## Principles

1. **Chrome recedes, content leads.** Controls rest at secondary contrast, with no borders and no fill until you interact with them. Only the URL pill has a resting fill.
2. **One edge.** The URL pill, the favourite tiles and the tab rows share one inset (`ArcSidebarInset`), so the sidebar reads as a single column.
3. **Feedback is a fill, not a border.** Hover, pressed and selected states are progressively stronger translucent fills (`ArcFillHover` → `ArcFillPressed` → `ArcFillSelected`). There are no outlines or focus rings on mouse-driven chrome.
4. **Show tools when they're needed.** Secondary actions, like copy link and site controls in the pill, appear on hover and fade away after. They're hidden, not just transparent, so they never take a stray click.
5. **Disabled is quieter, not gone.** A control that can't act (forward with no history) stays in place at tertiary contrast, so the layout never jumps.
6. **Native first.** Use real `NSPopover`, `NSMenu`, `NSSharingServicePicker` and system materials, so behaviour (Escape, click-outside, VoiceOver, light and dark) is free and correct.

## Vocabulary

These are the terms we use for the small interactions:

- **Microinteraction:** one small cycle of trigger → rules → feedback, such as hovering the pill to reveal its buttons, or copying a link and seeing "Copied".
- **Interaction states:** rest, hover, pressed, focus, selected/open, disabled and loading. They're separate dimensions: a control can be disabled and loading, or open and hovered. Design every combination that can actually happen.
- **Reveal on hover** (a form of *progressive disclosure*): secondary actions appear only where and when they're relevant. In-place reveals must also be reachable from the keyboard, for example with ⌘L or a menu.
- **Feedback:** an immediate, truthful answer to every action. It should happen where the action happened, and never report success before the action is done.
- **Affordance and anti-affordance:** a control should look as usable as it is. A dimmed forward arrow is an anti-affordance that says "not now".
- **Object constancy:** elements fade and move rather than popping in and out, so you can follow what changed.
- **Easing:** ease-out for things arriving and ease-in for things leaving, with short durations (`ArcDurationFast`, `ArcDurationMedium`). Animations must be interruptible.

## Tokens

| Group | Tokens | Notes |
| --- | --- | --- |
| Spacing | `ArcSpace1–4` (4, 8, 12, 16), `ArcSidebarInset` (6) | 4-pt grid |
| Radii | Chip 6, Small 7, Medium 8, Pill 10, Popover 14 | Always continuous corners (`ArcRound`) |
| Sizes | Top-row button 32 / icon 15, pill 36, pill button 28 / icon 13, popover 272 wide, tile 34, row icon 30, favicon 16, chip 22 (rounded square behind a row's action icon) | Hit areas are never smaller than 28 pt |
| Type | URL 13 regular, row title 13 medium, subtitle 11, section header 12 semibold, chip 12 medium, palette field 17 regular, palette row 14 medium, palette detail 13 regular, accessory ("Switch to Tab") 13 medium | System font only |
| Fill | Rest 8%, hover 11%, pressed 16%, selected 14%, tile 7% | White on dark chrome, black on light (about 60% of the dark alpha) |
| Icon colour | Secondary label, or tertiary when disabled | Never full-contrast labels in chrome |
| Panel colour | Tertiary text (white 58% / black 64%), panel tint (94% wash over the blur), panel border (white 12% / black 10%), text selection (white 24% / black 14%) | Tertiary is tuned to ~6:1 because the system tertiary label reads ~2:1 on the palette. The tint keeps the palette dark over white pages |
| Palette (⌘T) | Width 520 (content width − 2 × margin 24 at most), top at 30% of the web content, search row 52 with a 15-pt magnifying glass at 18, rows 34 with 6 gaps inside an 8 inset (a title takes at most 60% of a row that also shows a "— detail"), appears from scale 0.98 | Centred over the web content, not the window |
| URL editor (⌘L) | Width 1.55 × sidebar width, clamped to 300–420 and the window, rows 44, Dia's editor popover offset 0 from the pill | Its top-left sits on the pill's top-left, covering it |
| Motion | Fast 0.12 s (hover), medium 0.2 s (appear and crossfade), "Copied" held 1.2 s | Ease-out when appearing, ease-in when leaving. Instant when Reduce Motion is on (`ArcAnimate`) |

## Components

- **Top row:** the sidebar toggle sits at the leading edge (after the window buttons, or at the inset in full screen), and back, forward and reload sit trailing. Each is a 32 pt square with a medium-radius hover fill.
- **URL pill:** shows the host only (no scheme, no `www.`, the port kept for local servers). On hover, the copy-link and site-controls buttons fade in at the trailing edge and the host truncates to make room. Clicking the text opens the address editor.
- **Site controls popover:** in this order:
  1. a row of action tiles
  2. **Extensions**, a 4-column grid
  3. **Settings**, rows with a circular icon, a title and a state subtitle
  4. a hairline, then a footer with a security chip and a "…" menu
- **Command palette (⌘T):** a floating panel centred over the web content: a search row, a hairline, then up to eight rows. Open tabs end in "Switch to Tab" and an arrow chip, which turn full contrast on the highlighted row. It fades in from 0.98 scale and fades out.
- **URL editor (⌘L):** drops down from the URL pill, covering it: the site's favicon and the full URL (selected), then the current page, the site's root and related history before you type.
- **Feedback:** confirm in place. "Copied" replaces the host and the link icon becomes a checkmark, then both restore. No toasts for actions that happened where you clicked.

## Voice

Labels follow Arc's tone: short, plain and specific.

- **Actions** are Title Case verbs with an object: *Copy Link*, *Share*, *View Page Source*.
- **Settings** are a noun phrase plus a state: *Notifications*, then *Allowed*.
- **Descriptions** are one sentence in sentence case that says what changes for you: *"Buttons that appear in the URL bar when the pointer is over it."*
- **Leave out** exclamation marks, "please", jargon ("injected", "hook") and words like "simply" and "just".
- **Confirmations** are past tense and one word where possible: *Copied*.
- **Errors** say what to do next: *"Quit Dia first, then switch."*

## Checklist for new UI

- [ ] Sizes, radii, colours, fonts and durations all come from `ArcStyle.h`.
- [ ] It has hover, pressed and disabled states, and a selected state if it opens something.
- [ ] It looks right in light and dark mode, and with Increase Contrast and Reduce Motion on.
- [ ] Hidden controls are `hidden`, not just transparent.
- [ ] Labels follow the voice rules above.
