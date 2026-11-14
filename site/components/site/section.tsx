import * as React from "react"
import { RisoArt, type RisoVariant } from "@/components/site/riso-art"

// A page section: an optional quiet art layer behind it, a heading block, then content.
export function Section({
  id,
  eyebrow,
  title,
  intro,
  art,
  children,
}: {
  id: string
  eyebrow: string
  title: string
  intro?: React.ReactNode
  art?: RisoVariant
  children: React.ReactNode
}) {
  return (
    <section id={id} className="section" aria-labelledby={`${id}-title`} data-art={art}>
      {art && (
        <div className="section-art" aria-hidden>
          <RisoArt variant={art} />
        </div>
      )}
      <div className="wrap">
        <header className="section-head">
          <p className="eyebrow">{eyebrow}</p>
          <h2 id={`${id}-title`}>{title}</h2>
          {intro && <p className="lede">{intro}</p>}
        </header>
        {children}
      </div>
    </section>
  )
}
