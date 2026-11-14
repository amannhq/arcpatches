// Resolves each setting's pictures at build time from site/public/shots/settings/, which
// scripts/copy-shots.mjs fills from docs/screenshots/settings/. manifest.json there lists,
// per key, an "on" and "off" still and an optional looping APNG "demo", plus a display
// scale (images are rendered at 2x unless `scales` says otherwise). A setting with no
// pictures gets a text-only row; nothing here invents a placeholder.
import fs from "node:fs"
import path from "node:path"
import { BASE } from "@/lib/content"
import type { Demo, Setting } from "@/data/settings"

const dir = path.join(process.cwd(), "public", "shots", "settings")
const url = (file: string) => `${BASE}/shots/settings/${file}`

export type Picture = { src: string; width: number; height: number }
/** One state of a setting: its label, the value it sets, and its picture if there is one. */
export type State = { label: string; picture: Picture | null }
export type DemoAsset = { picture: Picture; poster: string | null }

type Item = { key: string; on?: string; off?: string; demo?: string }
type Manifest = { defaultScale?: number; scales?: Record<string, number>; items?: Item[] }

function loadManifest(): Manifest {
  const file = path.join(dir, "manifest.json")
  if (!fs.existsSync(file)) return {}
  try {
    return JSON.parse(fs.readFileSync(file, "utf8")) as Manifest
  } catch {
    return {}
  }
}

const manifest = loadManifest()
const items = new Map((manifest.items ?? []).map((i) => [i.key.replace(/^arcpatches\./, ""), i]))

/** A PNG's size in CSS pixels: its pixel size over the manifest's scale for that file. */
function picture(file: string | undefined): Picture | null {
  if (!file) return null
  const p = path.join(dir, file)
  if (!fs.existsSync(p)) return null
  const head = Buffer.alloc(24)
  const fd = fs.openSync(p, "r")
  fs.readSync(fd, head, 0, 24, 0)
  fs.closeSync(fd)
  const scale = manifest.scales?.[file] ?? manifest.defaultScale ?? 2
  return { src: url(file), width: Math.round(head.readUInt32BE(16) / scale), height: Math.round(head.readUInt32BE(20) / scale) }
}

/** The states the page offers for a setting, in the order of its options. For a
 *  multiple-choice setting, "on" pictures the first option and "off" the last (Dia's own). */
export function statesFor(s: Setting): State[] {
  const item = items.get(s.key)
  const on = picture(item?.on)
  const off = picture(item?.off)
  if (s.type === "int") {
    const last = s.options.length - 1
    return s.options.map((o, i) => ({ label: o.label, picture: i === 0 ? on : i === last ? off : null }))
  }
  const [offLabel, onLabel] = s.type === "shortcut" ? ["Before", "After"] : ["Off", "On"]
  return [
    { label: offLabel, picture: off },
    { label: onLabel, picture: on },
  ]
}

// The "Copied" feedback is shown by the copy link button and by ⌘⇧C alike. Its still,
// for Reduce Motion, is the pill with its buttons showing.
const DEMO_FILES: Partial<Record<string, string>> = { "arcShortcut.copyURL": "demo-copy-link.png" }
const DEMO_STILLS: Partial<Record<string, string>> = { "arcShortcut.copyURL": "sidebarPillButtons-on.png" }

export function demoFor(s: Setting): DemoAsset | null {
  const file = DEMO_FILES[s.key] ?? items.get(s.key)?.demo
  const pic = picture(file)
  if (!pic) return null
  const strip = picture(`${s.key}-on-strip.png`)
  const still = picture(DEMO_STILLS[s.key] ?? items.get(s.key)?.on)
  return { picture: pic, poster: strip?.src ?? still?.src ?? null }
}

export const DEMO_LABELS: Record<Demo, string> = {
  "pill-hover": "The pill's buttons fading in on hover",
  copied: "“Copied” fading in the pill",
  reload: "Reload spinning, then turning into stop",
  palette: "The ⌘T command bar opening and moving its highlight",
  "fullscreen-strip": "The full-screen strip at the top edge",
}
