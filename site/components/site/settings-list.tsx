import { Badge } from "@/components/ui/badge"
import { DemoVisual, StateVisual } from "@/components/site/setting-visual"
import { GROUPS, SETTINGS, defaultLabel, defaultsCommand, type Setting } from "@/data/settings"
import { checkSettings } from "@/lib/settings-check"
import { DEMO_LABELS, demoFor, statesFor } from "@/lib/visuals"

const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-")

function initialIndex(s: Setting): number {
  if (s.type === "int") return Math.max(0, s.options.findIndex((o) => o.value === s.default))
  if (s.type === "bool") return s.default ? 1 : 0
  return 1
}

function commandsFor(s: Setting): string[] | null {
  if (s.type === "bool") return [defaultsCommand(s, false)!, defaultsCommand(s, true)!]
  if (s.type === "int") return s.options.map((o) => defaultsCommand(s, o.value)!)
  return null
}

function SettingCard({ s }: { s: Setting }) {
  const id = `setting-${slug(s.key)}`
  return (
    <article className="glass setting" aria-labelledby={id}>
      <div className="setting-text">
        <h4 id={id}>{s.title}</h4>
        <p>{s.detail}</p>
        <dl>
          <div>
            <dt>Key</dt>
            <dd>
              <code>arcpatches.{s.key}</code>
            </dd>
          </div>
          <div>
            <dt>Default</dt>
            <dd>
              <Badge tone={s.type === "bool" ? (s.default ? "success" : "neutral") : "info"}>{defaultLabel(s)}</Badge>
            </dd>
          </div>
          {s.requires && (
            <div>
              <dt>Needs</dt>
              <dd>
                <code>{s.requires}</code>
              </dd>
            </div>
          )}
        </dl>
        {s.demo && (
          <figure className="demo">
            <DemoVisual demo={demoFor(s.demo)} label={DEMO_LABELS[s.demo]} />
            <figcaption>{DEMO_LABELS[s.demo]}</figcaption>
          </figure>
        )}
      </div>
      <StateVisual title={s.title} states={statesFor(s)} initial={initialIndex(s)} commands={commandsFor(s)} />
    </article>
  )
}

export function SettingsList() {
  checkSettings()
  return (
    <>
      <nav className="glass group-nav" aria-label="Setting groups">
        {GROUPS.map((g) => (
          <a key={g.name} href={`#${slug(g.name)}`}>
            {g.name}
          </a>
        ))}
      </nav>
      {GROUPS.map((g) => (
        <section key={g.name} id={slug(g.name)} className="setting-group" aria-labelledby={`${slug(g.name)}-title`}>
          <h3 id={`${slug(g.name)}-title`}>{g.name}</h3>
          <p className="lede">{g.blurb}</p>
          {SETTINGS.filter((s) => s.group === g.name).map((s) => (
            <SettingCard key={s.key} s={s} />
          ))}
        </section>
      ))}
    </>
  )
}
