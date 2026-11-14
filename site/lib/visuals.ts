// Resolves each setting's visuals from site/public/shots/settings/ at build time.
// Anything missing resolves to null, and the page draws a labelled placeholder instead.
import fs from "node:fs"
import path from "node:path"
import { BASE } from "@/lib/content"
import type { Demo, Setting } from "@/data/settings"

const dir = path.join(process.cwd(), "public", "shots", "settings")
const url = (file: string) => `${BASE}/shots/settings/${file}`
const exists = (file: string) => fs.existsSync(path.join(dir, file))

export type State = { label: string; src: string | null; file: string }

export type DemoAsset =
  | { kind: "image"; src: string; poster: string | null }
  | { kind: "frames"; frames: string[]; fps: number }
  | null

export function statesFor(s: Setting): State[] {
  const pick = (label: string, file: string): State => ({ label, file, src: exists(file) ? url(file) : null })
  if (s.type === "int") return s.options.map((o) => pick(o.label, `${s.key}-${o.value}.png`))
  const [off, on] = s.type === "shortcut" ? ["Before", "After"] : ["Off", "On"]
  return [pick(off, `${s.key}-off.png`), pick(on, `${s.key}-on.png`)]
}

export function demoFor(demo: Demo | undefined): DemoAsset {
  if (!demo) return null
  const poster = exists(`anim/${demo}-poster.png`) ? url(`anim/${demo}-poster.png`) : null
  for (const ext of ["webp", "apng", "gif"]) {
    if (exists(`anim/${demo}.${ext}`)) return { kind: "image", src: url(`anim/${demo}.${ext}`), poster }
  }
  const manifest = path.join(dir, "anim", demo, "manifest.json")
  if (fs.existsSync(manifest)) {
    try {
      const m = JSON.parse(fs.readFileSync(manifest, "utf8")) as { fps?: number; frames?: string[] }
      const frames = (m.frames ?? []).filter((f) => exists(`anim/${demo}/${f}`)).map((f) => url(`anim/${demo}/${f}`))
      if (frames.length) return { kind: "frames", frames, fps: Math.min(60, Math.max(1, m.fps ?? 12)) }
    } catch {
      // A malformed manifest falls back to the placeholder rather than failing the build.
    }
  }
  return null
}

export const DEMO_LABELS: Record<Demo, string> = {
  "pill-hover": "The pill's buttons fading in on hover",
  copied: "“Copied” crossfading in the pill",
  reload: "Reload spinning, then turning into stop",
  palette: "The ⌘T command bar appearing and moving its highlight",
  "fullscreen-strip": "The full-screen strip at the top edge",
}
