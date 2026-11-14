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

function SettingRow({ s }: { s: Setting }) {
  const id = `setting-${slug(s.key)}`
  const states = statesFor(s)
  const demo = demoFor(s)
  const pictured = !!demo || states.some((st) => st.picture)
  return (
    <article className="setting" data-text-only={!pictured || undefined} aria-labelledby={id}>
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
            <dd>{defaultLabel(s)}</dd>
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
        {demo && (
          <figure className="demo">
            <DemoVisual demo={demo} label={s.demo ? DEMO_LABELS[s.demo] : s.title} />
            <figcaption>{s.demo ? DEMO_LABELS[s.demo] : s.title}</figcaption>
          </figure>
        )}
      </div>
      <StateVisual
        title={s.title}
        states={states}
        initial={initialIndex(s)}
        commands={commandsFor(s)}
      />
    </article>
  )
}

export function SettingsList() {
  checkSettings()
  return (
    <>
      <nav className="group-nav" aria-label="Setting groups">
        {GROUPS.map((g) => (
          <a key={g.name} href={`#${slug(g.name)}`}>
            {g.name}
          </a>
        ))}
      </nav>
      {GROUPS.map((g) => (
        <section key={g.name} id={slug(g.name)} className="setting-group" aria-labelledby={`${slug(g.name)}-title`}>
          <header>
            <h3 id={`${slug(g.name)}-title`}>{g.name}</h3>
            <p>{g.blurb}</p>
          </header>
          {SETTINGS.filter((s) => s.group === g.name).map((s) => (
            <SettingRow key={s.key} s={s} />
          ))}
        </section>
      ))}
    </>
  )
}
