// Build-time guard: data/settings.ts must list every setting src/ defines, and docs/cli.md
// must document every one of them. Throws (failing `next build`) on any drift.
import fs from "node:fs"
import path from "node:path"
import { INTERNAL_KEYS, SETTINGS } from "@/data/settings"

const repo = path.join(process.cwd(), "..")

function sourceFiles(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name)
    return e.isDirectory() ? sourceFiles(p) : p.endsWith(".m") ? [p] : []
  })
}

function keysInSource(): Set<string> {
  const keys = new Set<string>()
  for (const file of sourceFiles(path.join(repo, "src"))) {
    const text = fs.readFileSync(file, "utf8")
    for (const m of text.matchAll(/NSString \*const \w+ = @"arcpatches\.(\w+)"/g)) keys.add(m[1])
    // Per-action keys: "arcpatches.arcShortcut.<id>" and "arcpatches.shortcut.<id>".
    const prefix = /ArcShortcuts\.m$/.test(file) ? "arcShortcut." : /Shortcuts\.m$/.test(file) ? "shortcut." : null
    if (prefix) for (const m of text.matchAll(/@"id": @"(\w+)"/g)) keys.add(prefix + m[1])
  }
  return keys
}

let checked = false

export function checkSettings() {
  if (checked) return
  checked = true
  const listed = new Set(SETTINGS.map((s) => s.key))
  const problems: string[] = []
  for (const key of keysInSource()) {
    if (!listed.has(key) && !INTERNAL_KEYS.includes(key)) problems.push(`src/ defines arcpatches.${key}, missing from site/data/settings.ts`)
  }
  const source = keysInSource()
  const cli = fs.readFileSync(path.join(repo, "docs/cli.md"), "utf8")
  for (const s of SETTINGS) {
    if (!source.has(s.key)) problems.push(`site/data/settings.ts lists ${s.key}, which src/ doesn't define`)
    if (!cli.includes(`| \`${s.key}\` |`)) problems.push(`docs/cli.md has no table row for ${s.key}`)
  }
  if (problems.length) throw new Error(`Settings list out of date:\n- ${problems.join("\n- ")}`)
}
