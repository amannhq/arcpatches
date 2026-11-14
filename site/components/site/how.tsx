import { Archive, Syringe, Undo2 } from "lucide-react"
import { Card } from "@/components/ui/card"
import { CodeBlock } from "@/components/ui/code-block"
import { Section } from "@/components/site/section"

const DIAGRAM = `/Applications/Dia.app ──clone──▶ pristine backup (APFS clone, no extra space)
          │
          └──▶ + arcpatches.dylib + weak load command ──re-sign──▶ patched Dia
                         │
                         └── at launch: adds Arc-style UI next to a few
                             of Dia's own views (sidebar, toolbar, editor)`

const STEPS = [
  {
    icon: Archive,
    title: "Back up",
    body: "Your Dia is cloned to ~/Library/Application Support/arcpatches first. An APFS clone takes no extra space, and it's checked against The Browser Company's signature.",
  },
  {
    icon: Syringe,
    title: "Patch in place",
    body: "A small library is added to a copy of Dia with a weak load command, then signed on your Mac. Nothing is downloaded from The Browser Company, and the binary's code isn't changed.",
  },
  {
    icon: Undo2,
    title: "Restore anytime",
    body: "One click, or --restore, puts the untouched original back. Dia's own updater keeps working, and ArcPatches patches each new version.",
  },
]

export function How() {
  return (
    <Section
      id="how"
      eyebrow="How it works"
      title="Patched in place. Restored in one click."
      intro="If a Dia update renames something a feature relies on, that feature switches itself off and the ArcPatches app tells you which one."
      art="dusk"
    >
      <div className="steps">
        {STEPS.map(({ icon: Icon, title, body }, i) => (
          <Card key={title} title={`${i + 1}. ${title}`} action={<Icon aria-hidden size={20} className="card-icon" />}>
            <p>{body}</p>
          </Card>
        ))}
      </div>
      <div className="glass diagram">
        <CodeBlock code={DIAGRAM} label="What the patch does" />
      </div>
    </Section>
  )
}
