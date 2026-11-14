// Every ArcPatches setting, as the code defines it. One source for the site's Settings page
// and its command line tables; lib/settings-check.ts fails the build if this list drifts
// from src/ or from docs/cli.md.
//
// Sources: src/core/Common.m (registerDefaults), src/features/*/ (keys and their own
// defaults), and src/features/preferences/PrefsPane.m (titles and descriptions).
//
// Visuals, copied from docs/screenshots/settings/ by scripts/copy-shots.mjs:
//   bool:      <key>-off.png and <key>-on.png
//   int:       <key>-<value>.png for each option
//   shortcut:  <key>-off.png (before) and <key>-on.png (after), key "shortcut.<id>"
//   demo:      anim/<demo>.webp | .apng (+ optional anim/<demo>-poster.png),
//              or anim/<demo>/manifest.json: { "fps": 12, "frames": ["000.png", …] }

export type SettingGroup = "Sidebar" | "Top row" | "Command bar" | "Shortcuts" | "Privacy" | "Performance" | "Tabs"

export const GROUPS: { name: SettingGroup; blurb: string }[] = [
  { name: "Sidebar", blurb: "The URL pill and the controls around it." },
  { name: "Top row", blurb: "The row beside the window buttons." },
  { name: "Command bar", blurb: "What ⌘T and ⌘L open." },
  { name: "Shortcuts", blurb: "Arc's copy shortcuts, and extra keys for profiles." },
  { name: "Tabs", blurb: "Tidy the sidebar's tabs from the keyboard." },
  { name: "Privacy", blurb: "AI entry points and network hosts." },
  { name: "Performance", blurb: "Chromium switches. These apply after restarting Dia." },
]

export type Demo = "pill-hover" | "copied" | "reload" | "palette" | "fullscreen-strip"

type Base = {
  key: string
  group: SettingGroup
  title: string
  detail: string
  /** Another setting this one needs, by key. */
  requires?: string
  demo?: Demo
}

export type Setting =
  | (Base & { type: "bool"; default: boolean })
  | (Base & { type: "int"; default: number; options: { value: number; label: string }[] })
  | (Base & { type: "shortcut"; default: string })

export const SETTINGS: Setting[] = [
  // Sidebar
  {
    key: "urlBarMode", group: "Sidebar", type: "int", default: 2,
    title: "URL bar position", detail: "Where the address and back, forward and reload controls live. ⌃⌘U switches between Dia's bar and this choice.",
    options: [{ value: 2, label: "In sidebar" }, { value: 1, label: "Hidden" }, { value: 0, label: "Top (Dia default)" }],
  },
  {
    key: "revealOnHover", group: "Sidebar", type: "bool", default: false,
    title: "Reveal top bar on hover", detail: "Move the pointer to the top edge of a page to show Dia's bar.",
  },
  {
    key: "sidebarShowsFullURL", group: "Sidebar", type: "bool", default: false,
    title: "Show full URL", detail: "Otherwise only the site's domain is shown.",
  },
  {
    key: "sidebarShowsNavButtons", group: "Sidebar", type: "bool", default: true, demo: "reload",
    title: "Back, forward and reload buttons", detail: "Shown next to the window controls. Reload turns into stop while a page loads.",
  },
  {
    key: "sidebarPillButtons", group: "Sidebar", type: "bool", default: true, demo: "pill-hover",
    title: "Copy link and site controls", detail: "Buttons that appear in the URL bar when the pointer is over it.",
  },
  {
    key: "topBarWhenSidebarHidden", group: "Sidebar", type: "bool", default: false,
    title: "Top bar while the sidebar is hidden", detail: "Shows Dia's bar when the sidebar is collapsed, as in focus mode. Off, like Arc: no URL bar until the sidebar is back.",
  },
  // Top row
  {
    key: "sidebarToggleButton", group: "Top row", type: "bool", default: true,
    title: "Sidebar toggle button", detail: "Shown after the window controls; hides and shows the sidebar with Dia's own command.",
  },
  {
    key: "downloadsInFooter", group: "Top row", type: "bool", default: true,
    title: "Downloads in the Sidebar Corner", detail: "Shows downloads at the bottom left of the sidebar, as Arc does, instead of next to the reload button.",
  },
  {
    key: "topRowProfileName", group: "Top row", type: "bool", default: false,
    title: "Profile name in top row", detail: "Dia shows the profile name in the sidebar header. Arc doesn't, and it can sit under the back and forward buttons.",
  },
  {
    key: "hideWindowButtonsInFullScreen", group: "Top row", type: "bool", default: true, demo: "fullscreen-strip",
    title: "Hide window buttons in full screen", detail: "The sidebar's top row then starts with the toggle, as in Arc.",
  },
  // Command bar
  {
    key: "commandBarStyle", group: "Command bar", type: "int", default: 2, demo: "palette",
    title: "Command bar", detail: "What ⌘T, ⌘L and the sidebar URL bar open. ArcPatches's bar finds tabs, history, bookmarks and commands.",
    options: [{ value: 2, label: "ArcPatches (Arc-style)" }, { value: 1, label: "Dia's editor" }, { value: 0, label: "Off (Dia default)" }],
  },
  {
    key: "cmdLFocusesSidebar", group: "Command bar", type: "bool", default: true, requires: "commandBarStyle = 1",
    title: "⌘L opens the sidebar URL bar", detail: "With Dia's editor as the command bar: open it at the sidebar instead of the top.",
  },
  // Shortcuts
  {
    key: "arcShortcut.copyURL", group: "Shortcuts", type: "bool", default: true, demo: "copied",
    title: "Copy URL ⌘⇧C", detail: "Without tracking parameters such as utm_source, fbclid and gclid.",
  },
  {
    key: "arcShortcut.copyMarkdown", group: "Shortcuts", type: "bool", default: true,
    title: "Copy URL as Markdown ⌘⇧⌥C", detail: "Copies [page title](URL), tracking parameters removed.",
  },
  {
    key: "extraShortcuts", group: "Shortcuts", type: "bool", default: false,
    title: "Extra shortcuts", detail: "Keys for tidying tabs and switching profiles. Click a shortcut in Settings to change it.",
  },
  {
    key: "profileNumberMods", group: "Shortcuts", type: "int", default: 262144, requires: "extraShortcuts",
    title: "Switch to profile 1–9", detail: "In the order Dia lists your profiles. macOS uses ⌃1… for Spaces when that's turned on in Keyboard Shortcuts.",
    options: [{ value: 262144, label: "⌃1 … ⌃9" }, { value: 786432, label: "⌃⌥1 … ⌃⌥9" }, { value: 1310720, label: "⌃⌘1 … ⌃⌘9" }, { value: 0, label: "None" }],
  },
  {
    key: "shortcut.nextProfile", group: "Shortcuts", type: "shortcut", default: "⌃⌥→", requires: "extraShortcuts",
    title: "Next profile", detail: "Switches the window to the next profile.",
  },
  {
    key: "shortcut.previousProfile", group: "Shortcuts", type: "shortcut", default: "⌃⌥←", requires: "extraShortcuts",
    title: "Previous profile", detail: "Switches the window to the previous profile.",
  },
  {
    key: "shortcut.moveTabToNextProfile", group: "Shortcuts", type: "shortcut", default: "⌃⌥⇧→", requires: "extraShortcuts",
    title: "Move tab to next profile", detail: "Takes the current tab with you.",
  },
  // Tabs
  {
    key: "shortcut.sortTabs", group: "Tabs", type: "shortcut", default: "⌃⌥S", requires: "extraShortcuts",
    title: "Sort tabs by domain", detail: "Orders this profile's tabs by site, then title. Pinned tabs and groups stay put.",
  },
  {
    key: "shortcut.groupTabs", group: "Tabs", type: "shortcut", default: "⌃⌥G", requires: "extraShortcuts",
    title: "Group tabs by domain", detail: "Puts tabs from the same site (two or more) into a group named after it.",
  },
  // Privacy
  {
    key: "hideAI", group: "Privacy", type: "bool", default: true,
    title: "Hide AI features", detail: "Chat menus and shortcuts, Chats in the sidebar, the Chat button, “Chat with this tab” on tab previews, “Add tabs or files”, and page content extraction.",
  },
  {
    key: "blockAI", group: "Privacy", type: "bool", default: false,
    title: "Block AI services", detail: "Dia's AI endpoints (chat, AI search, artifacts) and Google's Gemini API. Applies after restarting Dia.",
  },
  {
    key: "blockTelemetry", group: "Privacy", type: "bool", default: false,
    title: "Block telemetry", detail: "Datadog, Sentry, Segment, LaunchDarkly events and Dia's OpenTelemetry gateway. Applies after restarting Dia.",
  },
  // Performance
  {
    key: "disableOnDeviceAI", group: "Performance", type: "bool", default: true, requires: "hideAI",
    title: "Turn off on-device AI", detail: "Don't start Dia's local AI service process (about 40 MB), which otherwise classifies everything typed in the URL editor.",
  },
  {
    key: "rendererProcessLimit", group: "Performance", type: "int", default: 0,
    title: "Renderer process limit", detail: "Tabs share processes above this number: less memory with many tabs, but one crash can take several tabs with it.",
    options: [{ value: 0, label: "Chromium default" }, { value: 16, label: "16" }, { value: 8, label: "8" }, { value: 4, label: "4" }],
  },
  {
    key: "noBackgroundNetworking", group: "Performance", type: "bool", default: false,
    title: "Disable background networking", detail: "Stops Chromium's background updaters (components, field trials). May delay Safe Browsing list updates.",
  },
]

/** Keys ArcPatches writes for itself, which users shouldn't set. */
export const INTERNAL_KEYS = ["lastHiddenMode", "handoffExplained", "newTabPalette"]

export function defaultsCommand(s: Setting, value?: boolean | number): string | null {
  const key = `arcpatches.${s.key}`
  if (s.type === "shortcut") return null
  if (s.type === "bool") return `defaults write company.thebrowser.dia ${key} -bool ${(value ?? !s.default) ? "YES" : "NO"}`
  return `defaults write company.thebrowser.dia ${key} -int ${value ?? s.default}`
}

export function defaultLabel(s: Setting): string {
  if (s.type === "bool") return s.default ? "On" : "Off"
  if (s.type === "int") return s.options.find((o) => o.value === s.default)?.label ?? String(s.default)
  return s.default
}
