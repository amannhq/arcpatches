import { AsciiPanel } from "@/components/site/ascii-panel"
import { Section } from "@/components/site/section"
import { asciiNight } from "@/lib/ascii"
import { art } from "@/lib/content"

const DIAGRAM = `/Applications/Dia.app --clone--> backup (APFS clone, no extra space)
       |
       +--> + arcpatches.dylib + weak load command --re-sign--> patched Dia
                    |
                    +-- at launch: adds Arc-style UI next to a few
                        of Dia's own views (sidebar, toolbar, editor)`

const STEPS = [
  {
    title: "Back up",
    body: "Your Dia is cloned to ~/Library/Application Support/arcpatches first and checked against The Browser Company's signature. An APFS clone takes no extra space.",
  },
  {
    title: "Patch",
    body: "A small library is added to Dia with a weak load command, and the app is signed again on your Mac. The binary's code isn't changed, and nothing is downloaded from The Browser Company.",
  },
  {
    title: "Restore",
    body: "One click, or --restore, puts the untouched original back. Dia's updater keeps working, and ArcPatches patches each new version.",
  },
]

const COLS = 132
const ROWS = 40

// The one dark section: the night stock, an ASCII city behind a browser window.
export function How() {
  const night = art("night")
  const { lines, twinkle } = asciiNight(COLS, ROWS, 11)
  return (
    <Section
      id="how"
      tone="night"
      label="How it works"
      title="Patched in place. Restored in one click."
      intro="If a Dia update renames something a feature relies on, that feature turns itself off and the ArcPatches app tells you which one."
    >
      <div className="night-art">
        {night ? (
          // eslint-disable-next-line @next/next/no-img-element -- static export
          <img src={night} alt="" draggable={false} />
        ) : (
          <AsciiPanel lines={lines} twinkle={twinkle} cols={COLS} />
        )}
      </div>
      <dl className="ruled-grid three">
        {STEPS.map(({ title, body }) => (
          <div key={title}>
            <dt>{title}</dt>
            <dd>{body}</dd>
          </div>
        ))}
      </dl>
      <figure className="diagram">
        <figcaption className="label">What the patch does</figcaption>
        <pre tabIndex={0}>{DIAGRAM}</pre>
      </figure>
    </Section>
  )
}
