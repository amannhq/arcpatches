import * as React from "react"

// A page section on the paper (or the navy night stock): a small mono label over a rule,
// a heading, an optional line of intro, then content.
export function Section({
  id,
  label,
  title,
  intro,
  tone,
  children,
}: {
  id: string
  label: string
  title: string
  intro?: React.ReactNode
  tone?: "night"
  children: React.ReactNode
}) {
  return (
    <section id={id} className="section" data-tone={tone} aria-labelledby={`${id}-title`}>
      <div className="wrap">
        <header className="section-head">
          <p className="label">{label}</p>
          <h2 id={`${id}-title`}>{title}</h2>
          {intro && <p className="lede">{intro}</p>}
        </header>
        {children}
      </div>
    </section>
  )
}
