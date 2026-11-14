// prebuild: copies the rendered screenshots from docs/screenshots/ (top-level *.png and
// everything under settings/) into public/shots/, which is gitignored. Missing files are
// fine: the site draws a labelled placeholder for each one.
// SHOTS_DIR overrides the source folder, for trying the site with screenshots from elsewhere.
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const site = path.join(path.dirname(fileURLToPath(import.meta.url)), "..")
const src = path.resolve(process.env.SHOTS_DIR ?? path.join(site, "..", "docs", "screenshots"))
const dest = path.join(site, "public", "shots")
const MEDIA = /\.(png|webp|apng|gif|json)$/i

fs.rmSync(dest, { recursive: true, force: true })
fs.mkdirSync(dest, { recursive: true })

let copied = 0
function copy(from, to, recurse) {
  if (!fs.existsSync(from)) return
  for (const entry of fs.readdirSync(from, { withFileTypes: true })) {
    const a = path.join(from, entry.name)
    const b = path.join(to, entry.name)
    if (entry.isDirectory()) {
      if (recurse || entry.name === "settings") {
        fs.mkdirSync(b, { recursive: true })
        copy(a, b, true)
      }
    } else if (recurse ? MEDIA.test(entry.name) : /\.png$/i.test(entry.name)) {
      fs.copyFileSync(a, b)
      copied++
    }
  }
}
copy(src, dest, false)
console.log(`copy-shots: ${copied} file(s) from ${path.relative(site, src) || "."}`)
