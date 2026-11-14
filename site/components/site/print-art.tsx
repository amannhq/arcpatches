"use client"

import * as React from "react"
import { rng } from "@/lib/ascii"

// The hero's fallback illustration, used when site/art/hero.webp isn't there. An original
// procedural landscape in the manner of a screen print: a banded teal sky, white clouds,
// faceted slate peaks with snow, gold hills with a gold tree, a coral shrub band and a
// navy river bank. Each region is one flat ink; ordered dither appears only where two
// inks meet, plus a little grain. Drawn once per size at low resolution, scaled up with
// hard pixels. Deterministic and static.

type RGB = [number, number, number]
const hex = (h: string): RGB => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)) as RGB
const C = {
  sky: ["#1F5F86", "#2C7DA0", "#4F95B5", "#86B9CC"].map(hex),
  cloud: hex("#F4EFE6"),
  cloudShade: hex("#C9DAE2"),
  snow: hex("#F4EFE6"),
  snowShade: hex("#B9CCDB"),
  slate: hex("#5F7FA8"),
  slateDark: hex("#45618A"),
  gold: hex("#F2B33D"),
  goldDark: hex("#D48E2B"),
  coral: hex("#F2876B"),
  pink: hex("#F5A0A0"),
  navy: hex("#0F2A3D"),
  river: hex("#1D4560"),
}

const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map((v) => (v + 0.5) / 16)
const bayer = (x: number, y: number) => BAYER[(y & 3) * 4 + (x & 3)]

function noise1(seed: number) {
  const r = rng(seed)
  const lat = Array.from({ length: 256 }, r)
  const at = (x: number) => {
    const i = Math.floor(x)
    const f = x - i
    const s = f * f * (3 - 2 * f)
    return lat[i & 255] * (1 - s) + lat[(i + 1) & 255] * s
  }
  return (x: number) => at(x) * 0.62 + at(x * 2.3 + 9) * 0.26 + at(x * 5.7 + 31) * 0.12
}

// Clouds: rows of overlapping circles with flat bottoms, in normalized coordinates.
const CLOUDS: { x: number; y: number; w: number; r: number }[] = [
  { x: 0.1, y: 0.2, w: 0.2, r: 0.085 },
  { x: 0.46, y: 0.11, w: 0.12, r: 0.05 },
  { x: 0.74, y: 0.24, w: 0.24, r: 0.095 },
  { x: 0.96, y: 0.09, w: 0.1, r: 0.045 },
]

// Peaks: centre, summit height (fraction of the sky above the base line) and half-width.
const BASE_Y = 0.66
const PEAKS = [
  { x: -0.02, top: 0.42, w: 0.14 },
  { x: 0.16, top: 0.3, w: 0.17 },
  { x: 0.33, top: 0.4, w: 0.13 },
  { x: 0.52, top: 0.24, w: 0.19 },
  { x: 0.7, top: 0.38, w: 0.14 },
  { x: 0.86, top: 0.29, w: 0.16 },
  { x: 1.02, top: 0.4, w: 0.12 },
]

function draw(img: ImageData) {
  const { width: w, height: h, data } = img
  const grain = rng(97)
  const far = noise1(5)
  const mid = noise1(17)
  const shrubs = noise1(29)
  // The ridge is the lowest of the peaks' straight flanks, roughened a little; each
  // column remembers which peak owns it and on which side, for the light and shade faces.
  const ridge = new Float32Array(w)
  const owner = new Int16Array(w)
  const left = new Uint8Array(w)
  for (let x = 0; x < w; x++) {
    const u = x / w
    let best = Infinity
    PEAKS.forEach((p, i) => {
      const yy = p.top + (Math.abs(u - p.x) / p.w) * (BASE_Y - p.top)
      if (yy < best) {
        best = yy
        owner[x] = i
        left[x] = u < p.x ? 1 : 0
      }
    })
    ridge[x] = h * (best + 0.018 * (far(u * 40) - 0.5))
  }
  const hillA = Float32Array.from({ length: w }, (_, x) => h * (0.62 + 0.08 * mid((x / w) * 2.2 + 1)))
  const hillB = Float32Array.from({ length: w }, (_, x) => h * (0.7 + 0.07 * mid((x / w) * 1.6 + 7)))
  const shrubTop = Float32Array.from({ length: w }, (_, x) => {
    const u = (x / w) * 26
    return h * (0.8 - 0.03 * Math.abs(Math.sin(u)) - 0.03 * shrubs(x / w * 4))
  })
  const tree = { x: w * 0.74, y: h * 0.58, r: h * 0.075 }
  const cloudR = CLOUDS.map((c) => ({ ...c, cx: c.x * w, cy: c.y * h, rr: c.r * h }))

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const b = bayer(x, y)
      // Sky bands with dithered seams.
      const t = Math.min(0.999, (y / h / 0.62) * 0.92) * 4
      const band = Math.floor(t)
      const seam = t - band > 0.82 && (t - band - 0.82) / 0.18 > b
      let c = C.sky[Math.min(3, band + (seam ? 1 : 0))]
      // Clouds.
      for (const k of cloudR) {
        const bottom = k.cy + k.rr * 0.35
        if (y > bottom) continue
        let f = 0
        for (let i = 0; i < 5; i++) {
          const cx = k.cx + (i / 4 - 0.5) * k.w * w
          const cr = k.rr * (i === 1 || i === 2 ? 1 : 0.7)
          const cy = k.cy + (i === 1 || i === 2 ? 0 : k.rr * 0.25)
          f = Math.max(f, 1 - Math.hypot(x - cx, (y - cy) * 1.3) / cr)
        }
        if (f > 0.12 || (f > 0 && f / 0.12 > b)) c = y > bottom - k.rr * 0.32 ? C.cloudShade : C.cloud
      }
      // Peaks: slate faces, snow on the upper third of each.
      if (y >= ridge[x]) {
        const p = PEAKS[owner[x]]
        const lit = left[x] === 1
        c = lit ? C.slate : C.slateDark
        const depth = (y / h - p.top) / (BASE_Y - p.top)
        const snowline = 0.3 + 0.12 * (far(x * 0.09 + owner[x] * 13) - 0.5)
        if (depth < snowline || (depth < snowline + 0.04 && b > 0.55)) c = lit ? C.snow : C.snowShade
      }
      if (y >= hillA[x]) c = (y - hillA[x]) / h < 0.012 && b > 0.4 ? C.gold : C.goldDark
      if (y >= hillB[x]) c = C.gold
      // The gold tree on the near hill.
      const dt = Math.hypot(x - tree.x, (y - tree.y) * 1.1)
      if (Math.abs(x - tree.x) < Math.max(1, w * 0.004) && y > tree.y && y < tree.y + tree.r * 1.8) c = C.navy
      if (dt < tree.r || (dt < tree.r + 1.5 && b > 0.5)) c = x > tree.x + tree.r * 0.2 ? C.goldDark : C.gold
      // Coral shrubs, lit on their upper left.
      if (y >= shrubTop[x]) {
        const lit = y - shrubTop[x] < h * 0.018 && Math.sin((x / w) * 26) > 0.1
        c = lit ? C.pink : C.coral
      }
      // Navy bank and a dark river.
      const bank = h * (0.9 + 0.02 * Math.sin((x / w) * 7))
      if (y >= bank) {
        c = C.navy
        const riverMid = h * 0.955 + h * 0.012 * Math.sin((x / w) * 5 + 2)
        if (Math.abs(y - riverMid) < h * 0.014) c = grain() < 0.04 ? C.cloud : C.river
      }
      // Grain: a few cells print a touch light or dark.
      const g = grain()
      const o = (y * w + x) * 4
      const k = g < 0.03 ? 0.88 : g > 0.985 ? 1.08 : 1
      data[o] = c[0] * k
      data[o + 1] = c[1] * k
      data[o + 2] = c[2] * k
      data[o + 3] = 255
    }
  }
}

export function PrintArt({ pixel = 3 }: { pixel?: number }) {
  const ref = React.useRef<HTMLCanvasElement>(null)
  React.useEffect(() => {
    const canvas = ref.current
    if (!canvas) return
    let frame = 0
    let last = ""
    const paint = () => {
      const box = canvas.getBoundingClientRect()
      const w = Math.max(32, Math.ceil(box.width / pixel))
      const h = Math.max(32, Math.ceil(box.height / pixel))
      if (`${w}x${h}` === last) return
      last = `${w}x${h}`
      canvas.width = w
      canvas.height = h
      const ctx = canvas.getContext("2d")
      if (!ctx) return
      const img = ctx.createImageData(w, h)
      draw(img)
      ctx.putImageData(img, 0, 0)
    }
    const ro = new ResizeObserver(() => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(paint)
    })
    ro.observe(canvas)
    return () => {
      ro.disconnect()
      cancelAnimationFrame(frame)
    }
  }, [pixel])
  return <canvas ref={ref} className="print-art" aria-hidden />
}
