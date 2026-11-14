"use client"

import * as React from "react"

// Prints a server-generated ASCII drawing. With motion allowed and the panel on screen,
// a few stars and windows flicker slowly; otherwise it stays exactly as rendered.
export function AsciiPanel({ lines, twinkle, cols }: { lines: string[]; twinkle: [number, number][]; cols: number }) {
  const ref = React.useRef<HTMLPreElement>(null)
  const [rows, setRows] = React.useState(lines)
  React.useEffect(() => {
    const el = ref.current
    if (!el || !twinkle.length) return
    const still = matchMedia("(prefers-reduced-motion: reduce)")
    let visible = false
    let id = 0
    let seed = 1
    const next = () => {
      seed = (seed * 16807) % 2147483647
      return seed / 2147483647
    }
    const tick = () => {
      setRows((prev) => {
        const out = prev.map((r) => [...r])
        for (let i = 0; i < 6; i++) {
          const [x, y] = twinkle[Math.floor(next() * twinkle.length)]
          const original = lines[y][x]
          out[y][x] = out[y][x] === original ? (original === "#" ? "=" : original === "+" ? "." : " ") : original
        }
        return out.map((r) => r.join(""))
      })
    }
    const sync = () => {
      clearInterval(id)
      if (visible && !still.matches) id = window.setInterval(tick, 420)
      else setRows(lines)
    }
    const io = new IntersectionObserver(([e]) => {
      visible = e.isIntersecting
      sync()
    })
    io.observe(el)
    still.addEventListener("change", sync)
    return () => {
      clearInterval(id)
      io.disconnect()
      still.removeEventListener("change", sync)
    }
  }, [lines, twinkle])
  return (
    <pre ref={ref} className="ascii" aria-hidden style={{ "--cols": cols } as React.CSSProperties}>
      {rows.join("\n")}
    </pre>
  )
}
