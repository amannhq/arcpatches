// prebuild: copies what the site serves but doesn't keep in git.
//   - the rendered screenshots from docs/screenshots/ (top-level *.png and everything under
//     settings/) into public/shots/. Missing files are fine: the site draws a labelled
//     placeholder for each one.
//   - ../install.sh into public/install.sh, so the one-line install is served from the site.
//   - illustrations from site/art/ (hero.webp, hero-2.webp, night.webp) into public/art/.
//     Missing files are fine: the hero falls back to a procedural illustration.
// SHOTS_DIR overrides the screenshot folder, for trying the site with screenshots from elsewhere.
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const site = path.join(path.dirname(fileURLToPath(import.meta.url)), "..")
const pub = path.join(site, "public")
const src = path.resolve(process.env.SHOTS_DIR ?? path.join(site, "..", "docs", "screenshots"))
const dest = path.join(pub, "shots")
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

// The install script, served at /arcpatches/install.sh. It must exist: the hero links to it.
fs.copyFileSync(path.join(site, "..", "install.sh"), path.join(pub, "install.sh"))
console.log("copy-shots: install.sh")

const artSrc = path.join(site, "art")
const artDest = path.join(pub, "art")
fs.rmSync(artDest, { recursive: true, force: true })
fs.mkdirSync(artDest, { recursive: true })
const art = fs.existsSync(artSrc) ? fs.readdirSync(artSrc).filter((f) => /\.(webp|png|jpe?g|avif)$/i.test(f)) : []
for (const f of art) fs.copyFileSync(path.join(artSrc, f), path.join(artDest, f))
console.log(`copy-shots: ${art.length} illustration(s) from art/`)
