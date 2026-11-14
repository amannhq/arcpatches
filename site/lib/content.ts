// Build-time content, read from the repository's docs so the site never drifts from them.
// Runs only during `next build` (static export): server code, never shipped to the browser.
import fs from "node:fs"
import path from "node:path"

const repo = path.join(process.cwd(), "..")
const read = (file: string) => fs.readFileSync(path.join(repo, file), "utf8")

export const BASE = "/arcpatches"
export const REPO_URL = "https://github.com/amannhq/arcpatches"
export const SITE_URL = "https://amannhq.github.io/arcpatches"
export const INSTALL_CMD = `curl -fsSL ${SITE_URL}/install.sh | bash`
export const AGENT_DOC_URL = `${REPO_URL}/blob/main/docs/agent-install.md`

/** An illustration copied from site/art/ by scripts/copy-shots.mjs, or null when it isn't there. */
export function art(name: string): string | null {
  for (const ext of ["webp", "avif", "png", "jpg"]) {
    if (fs.existsSync(path.join(process.cwd(), "public", "art", `${name}.${ext}`))) return `${BASE}/art/${name}.${ext}`
  }
  return null
}

export function version(): string {
  return read("VERSION").trim()
}

/** The paste-ready prompt between the markers in docs/agent-install.md. */
export function agentPrompt(): string {
  const md = read("docs/agent-install.md")
  const m = md.match(/<!-- AGENT-PROMPT-START -->\n([\s\S]*?)\n<!-- AGENT-PROMPT-END -->/)
  if (!m) throw new Error("docs/agent-install.md: prompt markers not found")
  return m[1].trim() + "\n"
}

export type Row = string[]
export type Table = { title: string; head: Row; rows: Row[] }

function cells(line: string): Row {
  return line.trim().replace(/^\||\|$/g, "").split(/(?<!\\)\|/).map((c) => c.trim().replace(/\\\|/g, "|"))
}

/** Every Markdown table in docs/cli.md, titled by the heading above it. */
function cliTables(): Table[] {
  const lines = read("docs/cli.md").split("\n")
  const tables: Table[] = []
  let heading = ""
  for (let i = 0; i < lines.length; i++) {
    const h = lines[i].match(/^#{2,3} (.*)/)
    if (h) heading = h[1].replace(/`/g, "")
    if (lines[i].startsWith("|") && lines[i + 1]?.startsWith("| ---")) {
      const head = cells(lines[i])
      const rows: Row[] = []
      for (i += 2; lines[i]?.startsWith("|"); i++) rows.push(cells(lines[i]))
      tables.push({ title: heading, head, rows })
    }
  }
  return tables
}

export function cliFlags(): Table {
  const t = cliTables().find((t) => t.head[0] === "Flag")
  if (!t) throw new Error("docs/cli.md: flag table not found")
  return t
}

/** A screenshot copied in by scripts/copy-shots.mjs, with its pixel size, or null when missing. */
export function shot(name: string): { src: string; width: number; height: number } | null {
  const file = path.join(process.cwd(), "public", "shots", `${name}.png`)
  if (!fs.existsSync(file)) return null
  // A PNG's IHDR chunk holds the width and height at bytes 16–23.
  const head = Buffer.alloc(24)
  const fd = fs.openSync(file, "r")
  fs.readSync(fd, head, 0, 24, 0)
  fs.closeSync(fd)
  return { src: `${BASE}/shots/${name}.png`, width: head.readUInt32BE(16), height: head.readUInt32BE(20) }
}
