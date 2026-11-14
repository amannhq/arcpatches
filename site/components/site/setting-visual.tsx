"use client"

import * as React from "react"
import { CodeBlock } from "@/components/ui/code-block"
import { Segmented } from "@/components/ui/segmented-control"
import { RisoArt } from "@/components/site/riso-art"
import type { DemoAsset, State } from "@/lib/visuals"

function Placeholder({ text }: { text: string }) {
  return (
    <div data-shot-placeholder>
      <RisoArt variant="frame" pixel={2} />
      <span>{text}</span>
    </div>
  )
}

// The setting's states (Off/On, or each option) stacked, cross-fading as the kit's
// segmented control changes. Every image stays in the page so switching is instant.
// The command line for the chosen state follows the control too.
export function StateVisual({
  title,
  states,
  initial,
  commands,
}: {
  title: string
  states: State[]
  initial: number
  commands: string[] | null
}) {
  const [index, setIndex] = React.useState(initial)
  return (
    <div className="state-visual">
      <div className="stack">
        {states.map((s, i) => (
          <div key={s.file} className="layer" data-active={i === index || undefined} aria-hidden={i !== index}>
            {s.src ? (
              // eslint-disable-next-line @next/next/no-img-element -- static export
              <img src={s.src} alt={`${title}: ${s.label}`} loading="lazy" decoding="async" draggable={false} />
            ) : (
              <Placeholder text={`${title}: ${s.label} (still coming)`} />
            )}
          </div>
        ))}
      </div>
      <Segmented
        label={`Show ${title}`}
        options={states.map((s) => s.label)}
        defaultValue={states[initial].label}
        onValueChange={(label) => setIndex(Math.max(0, states.findIndex((s) => s.label === label)))}
      />
      {commands ? (
        <CodeBlock code={commands[index]} language="sh" label={`Set to ${states[index].label}`} />
      ) : (
        <p className="note">Change this key in Dia: Settings → ArcPatches → Shortcuts.</p>
      )}
    </div>
  )
}

function usePlaying(ref: React.RefObject<HTMLElement | null>) {
  const [visible, setVisible] = React.useState(false)
  const [still, setStill] = React.useState(true)
  React.useEffect(() => {
    const media = matchMedia("(prefers-reduced-motion: reduce)")
    const update = () => setStill(media.matches)
    update()
    media.addEventListener("change", update)
    const el = ref.current
    const io = el ? new IntersectionObserver(([e]) => setVisible(e.isIntersecting), { rootMargin: "100px" }) : null
    if (el && io) io.observe(el)
    return () => {
      media.removeEventListener("change", update)
      io?.disconnect()
    }
  }, [ref])
  return visible && !still
}

// A PNG sequence played by swapping frames; pauses off-screen and under Reduce Motion,
// where it holds the first frame as a poster.
function FramePlayer({ frames, fps, alt }: { frames: string[]; fps: number; alt: string }) {
  const ref = React.useRef<HTMLDivElement>(null)
  const playing = usePlaying(ref)
  const [frame, setFrame] = React.useState(0)
  React.useEffect(() => {
    if (!playing) return
    const id = setInterval(() => setFrame((f) => (f + 1) % frames.length), 1000 / fps)
    return () => clearInterval(id)
  }, [playing, frames.length, fps])
  React.useEffect(() => {
    // Warm the cache so the first loop doesn't flicker.
    frames.forEach((f) => (new Image().src = f))
  }, [frames])
  return (
    <div ref={ref} className="frames">
      {/* eslint-disable-next-line @next/next/no-img-element -- static export */}
      <img src={frames[playing ? frame : 0]} alt={alt} draggable={false} />
    </div>
  )
}

// Under Reduce Motion an animated image shows its poster, or else the setting's own still.
export function DemoVisual({ demo, label, still }: { demo: DemoAsset; label: string; still: string | null }) {
  if (!demo) return <Placeholder text={`${label} (animation coming)`} />
  if (demo.kind === "frames") return <FramePlayer frames={demo.frames} fps={demo.fps} alt={label} />
  const poster = demo.poster ?? still
  return (
    <picture>
      {poster && <source media="(prefers-reduced-motion: reduce)" srcSet={poster} />}
      {/* eslint-disable-next-line @next/next/no-img-element -- static export */}
      <img src={demo.src} alt={label} loading="lazy" decoding="async" draggable={false} />
    </picture>
  )
}
