"use client"

import * as React from "react"
import { Segmented } from "@/components/ui/segmented-control"
import { Command } from "@/components/site/command"
import type { DemoAsset, State } from "@/lib/visuals"

// The setting's states under the kit's segmented control. When any state has a picture,
// the pictures sit stacked in one ink frame and cross-fade as the control changes; a state
// without one says so in the frame. The command for the chosen state follows the control.
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
  const pics = states.flatMap((s) => (s.picture ? [s.picture] : []))
  const frame = pics.length
    ? { maxWidth: Math.max(...pics.map((p) => p.width)), aspect: `${pics[0].width} / ${pics[0].height}` }
    : null
  return (
    <div className="state-visual">
      {frame && (
        <div className="stack" style={{ maxWidth: frame.maxWidth, aspectRatio: frame.aspect }}>
          {states.map((s, i) => (
            <div key={s.label} className="layer" data-active={i === index || undefined} aria-hidden={i !== index}>
              {s.picture ? (
                // eslint-disable-next-line @next/next/no-img-element -- static export
                <img src={s.picture.src} alt={`${title}: ${s.label}`} loading="lazy" decoding="async" draggable={false} />
              ) : (
                <p className="no-picture">{s.label}: Dia&rsquo;s own interface, not pictured.</p>
              )}
            </div>
          ))}
        </div>
      )}
      {states.length > 1 && (
        <Segmented
          label={title}
          options={states.map((s) => s.label)}
          defaultValue={states[initial].label}
          onValueChange={(label) => setIndex(Math.max(0, states.findIndex((s) => s.label === label)))}
        />
      )}
      {commands ? (
        <Command code={commands[index]} label={`Set to ${states[index].label}`} wrap />
      ) : (
        <p className="note">Change this key in Dia: Settings → ArcPatches → Shortcuts.</p>
      )}
    </div>
  )
}

// A looping APNG. Under Reduce Motion it shows a still instead, when there is one.
export function DemoVisual({ demo, label }: { demo: DemoAsset; label: string }) {
  const { picture, poster } = demo
  return (
    <picture style={{ maxWidth: picture.width }}>
      {poster && <source media="(prefers-reduced-motion: reduce)" srcSet={poster} />}
      {/* eslint-disable-next-line @next/next/no-img-element -- static export */}
      <img
        src={picture.src}
        alt={label}
        width={picture.width}
        height={picture.height}
        loading="lazy"
        decoding="async"
        draggable={false}
      />
    </picture>
  )
}
