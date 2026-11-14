"use client"

import * as React from "react"

// Original procedural art, drawn once per size on a low-resolution canvas and scaled up
// with hard pixels: a banded sky, a soft sun, layered hills from smooth noise, flat
// palette fills mixed by an 8×8 ordered (Bayer) dither, and grain. Nothing is traced or
// sampled from an image. Static: no animation, so reduced-motion needs nothing extra.

export type RisoVariant = "hero" | "night" | "dusk" | "frame"

// The print palette, darkest to lightest: near-black, deep teal, teal, coral, amber, bone.
const INKS: [number, number, number][] = [
  [11, 20, 24],
  [14, 58, 72],
  [27, 84, 104],
  [255, 138, 112],
  [242, 169, 34],
  [243, 237, 226],
]
const TOP = INKS.length - 1

const BAYER = (() => {
  // 8×8 Bayer matrix, as thresholds in (0, 1).
  let m = [[0]]
  for (let n = 1; n < 8; n *= 2) {
    const next: number[][] = []
    for (let y = 0; y < n * 2; y++) {
      next.push([])
      for (let x = 0; x < n * 2; x++) {
        const q = (y < n ? 0 : 2) + (x < n ? 0 : 1)
        next[y].push(4 * m[y % n][x % n] + [0, 2, 3, 1][q])
      }
    }
    m = next
  }
  return m.map((row) => row.map((v) => (v + 0.5) / 64))
})()

function rng(seed: number) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

// Smooth 1-D value noise with a few octaves, for hill ridges.
function ridgeNoise(seed: number) {
  const r = rng(seed)
  const lattice = Array.from({ length: 512 }, r)
  const at = (x: number) => {
    const i = Math.floor(x)
    const f = x - i
    const s = f * f * (3 - 2 * f)
    return lattice[i & 511] * (1 - s) + lattice[(i + 1) & 511] * s
  }
  // Ridged: folding the noise at its midpoint turns rounded hills into peaks.
  return (x: number) => {
    const n = at(x) * 0.6 + at(x * 2.3 + 17) * 0.28 + at(x * 5.1 + 41) * 0.12
    return Math.pow(1 - Math.abs(2 * n - 1), 1.4)
  }
}

type Layer = { base: number; amp: number; freq: number; level: number; seed: number }

const SCENES: Record<Exclude<RisoVariant, "frame">, { sky: [number, number]; horizon: number; sun?: [number, number, number]; stars: number; layers: Layer[] }> = {
  hero: {
    sky: [1.05, 3.55],
    horizon: 0.66,
    sun: [0.7, 0.36, 0.09],
    stars: 0.0016,
    layers: [
      { base: 0.62, amp: 0.11, freq: 2.2, level: 2.35, seed: 3 },
      { base: 0.7, amp: 0.1, freq: 2.8, level: 1.8, seed: 7 },
      { base: 0.78, amp: 0.09, freq: 3.4, level: 1.25, seed: 11 },
      { base: 0.86, amp: 0.07, freq: 4.2, level: 0.7, seed: 19 },
      { base: 0.95, amp: 0.05, freq: 5.5, level: 0.12, seed: 23 },
    ],
  },
  dusk: {
    sky: [0.7, 2.4],
    horizon: 0.7,
    sun: [0.24, 0.48, 0.07],
    stars: 0.001,
    layers: [
      { base: 0.66, amp: 0.1, freq: 2.6, level: 1.5, seed: 31 },
      { base: 0.77, amp: 0.08, freq: 3.6, level: 0.85, seed: 37 },
      { base: 0.88, amp: 0.06, freq: 5, level: 0.2, seed: 41 },
    ],
  },
  night: {
    sky: [0.25, 1.35],
    horizon: 0.8,
    stars: 0.0025,
    layers: [
      { base: 0.8, amp: 0.08, freq: 2.4, level: 0.95, seed: 53 },
      { base: 0.9, amp: 0.06, freq: 3.8, level: 0.4, seed: 59 },
    ],
  },
}

function ink(level: number, x: number, y: number, out: Uint8ClampedArray, o: number) {
  const v = Math.min(TOP, Math.max(0, level))
  const lo = Math.floor(v)
  const c = INKS[v - lo > BAYER[y & 7][x & 7] ? Math.min(TOP, lo + 1) : lo]
  out[o] = c[0]
  out[o + 1] = c[1]
  out[o + 2] = c[2]
  out[o + 3] = 255
}

function drawScene(img: ImageData, variant: Exclude<RisoVariant, "frame">) {
  const { width: w, height: h, data } = img
  const s = SCENES[variant]
  const grain = rng(97)
  const ridges = s.layers.map((l) => {
    const n = ridgeNoise(l.seed)
    return Float32Array.from({ length: w }, (_, x) => h * (l.base - 1.8 * l.amp * n((x / w) * l.freq + l.seed)))
  })
  const sun = s.sun && { x: s.sun[0] * w, y: s.sun[1] * h, r: s.sun[2] * Math.min(w, h * 1.6) }
  for (let y = 0; y < h; y++) {
    // Banded sky: a vertical ramp stepped into thirds of an ink, dithered across each step.
    const t = Math.min(1, y / (h * s.horizon))
    const sky = s.sky[0] + (s.sky[1] - s.sky[0]) * t * t
    for (let x = 0; x < w; x++) {
      let level = Math.floor(sky * 3) / 3 + 0.01
      let glow = 0
      if (sun) {
        const d = Math.hypot(x - sun.x, (y - sun.y) * 1.05)
        glow = Math.exp(-((d / (sun.r * 3.2)) ** 2))
        level += 1.5 * glow
        if (d < sun.r) level = d > sun.r * 0.9 ? 4.2 : 5
      } else if (grain() < s.stars * (1 - t)) {
        level = 4.6
      }
      if (grain() < s.stars * 0.5 * (1 - t)) level = Math.max(level, 4.4)
      for (let i = 0; i < ridges.length; i++) {
        const top = ridges[i][x]
        if (y < top) continue
        const depth = Math.min(1, (y - top) / (h * 0.22))
        level = s.layers[i].level - 0.45 * depth + 0.6 * glow * (1 - i / ridges.length)
        if (y - top < 1.5 && sun && i < 2) level += 1.1 // rim light on the far ridges
      }
      ink(level + (grain() - 0.5) * 0.34, x, y, data, (y * w + x) * 4)
    }
  }
}

// An abstract browser window for a missing screenshot: a sidebar column with a pill and
// rows, a content pane, all in the same inks.
function drawFrame(img: ImageData) {
  const { width: w, height: h, data } = img
  const grain = rng(13)
  const pad = Math.round(Math.min(w, h) * 0.08)
  const side = Math.round(w * 0.27)
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const t = y / h
      let level = 1.1 + 1.6 * t * t // backdrop
      const inWin = x > pad && x < w - pad && y > pad && y < h - pad
      if (inWin) {
        const lx = x - pad
        const ly = y - pad
        const wh = h - pad * 2
        if (lx < side) {
          level = 0.55 + 0.2 * (ly / wh)
          const pillTop = Math.round(wh * 0.12)
          if (ly > pillTop && ly < pillTop + Math.round(wh * 0.07) && lx > 6 && lx < side - 6) level = 2.15
          const row = Math.floor((ly - wh * 0.28) / (wh * 0.085))
          const inRow = (ly - wh * 0.28) % (wh * 0.085) < wh * 0.05
          if (row >= 0 && row < 6 && inRow && lx > 8 && lx < side - 8 - row * 6) level = row === 1 ? 3.4 : 1.35
          if (ly < wh * 0.07 && lx > 6 && lx < 30 && lx % 9 < 5) level = [3.6, 4.2, 2.4][Math.floor((lx - 6) / 9)] ?? level
        } else {
          const u = (lx - side) / (w - pad * 2 - side)
          level = 2.2 + 1.4 * (ly / wh) + 0.6 * u
          if (ly > wh * 0.18 && ly < wh * 0.24 && u > 0.08 && u < 0.6) level = 5
          if (ly > wh * 0.3 && ly < wh * 0.33 && u > 0.08 && u < 0.85) level = 4.6
          if (ly > wh * 0.37 && ly < wh * 0.4 && u > 0.08 && u < 0.7) level = 4.6
        }
      }
      ink(level + (grain() - 0.5) * 0.3, x, y, data, (y * w + x) * 4)
    }
  }
}

export function RisoArt({ variant, pixel = 3, className }: { variant: RisoVariant; pixel?: number; className?: string }) {
  const ref = React.useRef<HTMLCanvasElement>(null)
  React.useEffect(() => {
    const canvas = ref.current
    if (!canvas) return
    let frame = 0
    let last = ""
    const draw = () => {
      const box = canvas.getBoundingClientRect()
      const w = Math.max(16, Math.ceil(box.width / pixel))
      const h = Math.max(16, Math.ceil(box.height / pixel))
      if (`${w}x${h}` === last) return
      last = `${w}x${h}`
      canvas.width = w
      canvas.height = h
      const ctx = canvas.getContext("2d")
      if (!ctx) return
      const img = ctx.createImageData(w, h)
      if (variant === "frame") drawFrame(img)
      else drawScene(img, variant)
      ctx.putImageData(img, 0, 0)
      canvas.dataset.ready = ""
    }
    const observer = new ResizeObserver(() => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(draw)
    })
    observer.observe(canvas)
    return () => {
      observer.disconnect()
      cancelAnimationFrame(frame)
    }
  }, [variant, pixel])
  return <canvas ref={ref} aria-hidden data-riso={variant} className={className} />
}
