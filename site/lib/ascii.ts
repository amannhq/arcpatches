// Original ASCII drawings, generated from a seed so every build prints the same thing.
// Pure functions with no browser or Node APIs: the server renders them into the HTML and
// the client can animate a copy without a hydration mismatch.

export const RAMP = " .:-=+*#%@"

export function rng(seed: number) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

export function seedOf(text: string) {
  let h = 2166136261
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619)
  return h >>> 0
}

// 4×4 Bayer thresholds, for ordered dither in character space.
const B4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map((v) => (v + 0.5) / 16)
const shade = (v: number, x: number, y: number) => {
  const s = Math.max(0, Math.min(1, v)) * (RAMP.length - 1)
  const lo = Math.floor(s)
  return RAMP[Math.min(RAMP.length - 1, lo + (s - lo > B4[(y & 3) * 4 + (x & 3)] ? 1 : 0))]
}

type Grid = string[][]
const blank = (cols: number, rows: number): Grid => Array.from({ length: rows }, () => Array(cols).fill(" "))
const put = (g: Grid, x: number, y: number, ch: string) => {
  if (y >= 0 && y < g.length && x >= 0 && x < g[0].length) g[y][x] = ch
}
const text = (g: Grid, x: number, y: number, s: string) => [...s].forEach((ch, i) => put(g, x + i, y, ch))

function box(g: Grid, x0: number, y0: number, w: number, h: number, fill = " ") {
  for (let y = y0; y <= y0 + h; y++)
    for (let x = x0; x <= x0 + w; x++) {
      const edgeY = y === y0 || y === y0 + h
      const edgeX = x === x0 || x === x0 + w
      put(g, x, y, edgeY && edgeX ? "+" : edgeY ? "-" : edgeX ? "|" : fill)
    }
}

// A browser window: traffic lights, a sidebar with the URL pill and tab rows, a page.
function browser(g: Grid, x0: number, y0: number, w: number, h: number, r: () => number) {
  box(g, x0, y0, w, h)
  text(g, x0 + 2, y0 + 1, "o o o   <  >  C")
  const side = Math.max(14, Math.round(w * 0.3))
  for (let y = y0 + 1; y < y0 + h; y++) put(g, x0 + side, y, "|")
  const pill = "( example.com )".slice(0, side - 3)
  text(g, x0 + 2, y0 + 3, pill)
  for (let i = 0; i < Math.min(6, h - 7); i++) {
    const len = Math.max(4, Math.round((side - 6) * (0.45 + 0.5 * r())))
    text(g, x0 + 2, y0 + 5 + i, (i === 1 ? "# " : "- ") + "=".repeat(len - 2))
  }
  // The page: a headline bar, lines of text, a dithered picture.
  const px = x0 + side + 3
  const pw = w - side - 5
  text(g, px, y0 + 2, "#".repeat(Math.round(pw * 0.55)))
  for (let i = 0; i < 3; i++) text(g, px, y0 + 4 + i, ":".repeat(Math.round(pw * (0.9 - i * 0.12))))
  for (let y = y0 + 8; y < y0 + h - 1; y++)
    for (let x = px; x < px + pw; x++) {
      // A small print of peaks: dotted sky, a ridge, snow, dense slopes.
      const u = (x - px) / pw
      const v = (y - y0 - 8) / Math.max(1, h - 9)
      const ridge = 0.25 + 0.5 * Math.min(Math.abs(u - 0.3) * 2.2, Math.abs(u - 0.72) * 2.6, 1)
      const depth = v - ridge
      put(g, x, y, depth < 0 ? shade(0.08 + 0.1 * v, x, y) : depth < 0.08 ? "-" : shade(0.45 + depth * 0.9, x, y))
    }
}

/** A night city behind a browser window, white on navy. Returns rows of text and the
 *  cells that may twinkle (stars and lit windows). */
export function asciiNight(cols: number, rows: number, seed = 7) {
  const r = rng(seed)
  const g = blank(cols, rows)
  const twinkle: [number, number][] = []
  // Sky: sparse stars, thicker toward the top.
  for (let y = 0; y < rows; y++)
    for (let x = 0; x < cols; x++)
      if (r() < 0.035 * (1 - y / rows)) {
        g[y][x] = r() < 0.2 ? "+" : r() < 0.5 ? "." : "'"
        twinkle.push([x, y])
      }
  // Moon.
  const mx = Math.round(cols * 0.82)
  const my = Math.round(rows * 0.18)
  for (let y = 0; y < rows; y++)
    for (let x = 0; x < cols; x++) {
      // A crescent: the disc minus a second disc set up and to the left.
      const d = Math.hypot((x - mx) * 0.5, y - my)
      const cut = Math.hypot((x - mx + 2.4) * 0.5, y - my + 0.8)
      if (d < 3.4 && cut > 3) g[y][x] = d > 2.8 ? "*" : "@"
    }
  // Skyline: buildings of varied height, windows lit at random.
  for (let x = 0; x < cols; ) {
    const bw = 3 + Math.floor(r() * 8)
    const bh = Math.round(rows * (0.18 + r() * (x % 3 === 0 ? 0.5 : 0.32)))
    const top = rows - bh
    for (let bx = x; bx < Math.min(cols, x + bw); bx++)
      for (let y = top; y < rows; y++) {
        const edge = bx === x || bx === x + bw - 1 || y === top
        const lit = !edge && (bx - x) % 2 === 1 && (y - top) % 2 === 1 && r() < 0.42
        g[y][bx] = edge ? (y === top ? "_" : ":") : lit ? "#" : "."
        if (lit) twinkle.push([bx, y])
      }
    if (r() < 0.25 && top > 2) put(g, x + Math.floor(bw / 2), top - 1, "|")
    x += bw + (r() < 0.3 ? 1 : 0)
  }
  // The browser, set over the city.
  const bw = Math.min(cols - 8, Math.max(40, Math.round(cols * 0.56)))
  const bh = Math.min(rows - 6, Math.max(14, Math.round(rows * 0.62)))
  browser(g, Math.round(cols * 0.08), Math.round(rows * 0.16), bw, bh, r)
  const keep = twinkle.filter(([x, y]) => g[y][x] !== " " && "+.'#".includes(g[y][x]))
  return { lines: g.map((row) => row.join("")), twinkle: keep }
}

/** A stand-in for a missing screenshot: a browser window over a dithered field, ink on paper. */
export function asciiFrame(cols: number, rows: number, seed: number): string {
  const r = rng(seed)
  const g = blank(cols, rows)
  const phase = r() * 6
  for (let y = 0; y < rows; y++)
    for (let x = 0; x < cols; x++) {
      const v = 0.08 + 0.22 * (y / rows) + 0.06 * Math.sin(x * 0.18 + phase)
      g[y][x] = shade(v, x, y)
    }
  browser(g, 3, 1, cols - 7, rows - 3, r)
  return g.map((row) => row.join("")).join("\n")
}
