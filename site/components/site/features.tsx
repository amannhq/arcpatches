import { Section } from "@/components/site/section"
import { Shot } from "@/components/site/shot"

const SHOWCASE = [
  {
    shot: "sidebar",
    label: "Sidebar",
    title: "The URL bar lives in the sidebar",
    body: "The current site sits at the top of the sidebar. Back, forward and reload sit beside the window buttons, with a sidebar toggle after them.",
    alt: "The sidebar with the URL pill and navigation buttons",
  },
  {
    shot: "pill-hover",
    label: "URL pill",
    title: "Buttons appear on hover",
    body: "Point at the URL pill and two buttons show at its edge: copy link and site controls. Move away and they hide again.",
    alt: "The URL pill with its hover buttons showing",
  },
  {
    shot: "site-controls",
    label: "Site controls",
    title: "One popover per site",
    body: "Actions, extensions, permissions and the connection's security, in the order Arc used.",
    alt: "The site controls popover",
  },
  {
    shot: "palette",
    label: "⌘T",
    title: "A command bar for tabs, history and bookmarks",
    body: "Search open tabs, history and bookmarks, run browser commands and open chrome:// pages. Sites complete as you type.",
    alt: "The ⌘T command bar over a page",
  },
  {
    shot: "editor",
    label: "⌘L",
    title: "Edit the address in place",
    body: "The editor drops down over the pill with the full URL selected. Below it: the current page, the site's root and related history.",
    alt: "The ⌘L address editor below the URL pill",
  },
]

const EXTRAS = [
  {
    title: "Pages use the whole window",
    body: "Dia's top toolbar is gone. Turn on “Reveal top bar on hover” to bring it back at the top edge.",
  },
  {
    title: "Arc's shortcuts",
    body: "⌘S toggles the sidebar, ⌘⇧C copies a clean URL and ⌘⇧⌥C copies a Markdown link. Each one can be turned off.",
  },
  {
    title: "AI features hidden",
    body: "Chat entry points are hidden and the on-device model doesn't start. AI and telemetry hosts can be blocked too.",
  },
  {
    title: "Patched again after updates",
    body: "Dia's updater keeps working. The menu bar app patches each new version, and restores the original in one click.",
  },
]

export function Features() {
  return (
    <Section
      id="features"
      label="Features"
      title="The Arc parts Dia left out."
      intro="Drawn natively, at Arc's sizes. Each feature can be turned off in Dia under Settings → ArcPatches."
    >
      <div className="lead-shot">
        <Shot name="hero" alt="Dia with ArcPatches: the URL bar and navigation in the sidebar" priority maxHeight={720} />
      </div>
      <ul className="rows">
        {SHOWCASE.map((f, i) => (
          <li key={f.shot} className="row" data-flip={i % 2 === 1 || undefined}>
            <div className="row-text">
              <p className="label">{f.label}</p>
              <h3>{f.title}</h3>
              <p>{f.body}</p>
            </div>
            <div className="row-media">
              <Shot name={f.shot} alt={f.alt} />
            </div>
          </li>
        ))}
      </ul>
      <h3 className="sub-head">Also</h3>
      <dl className="ruled-grid">
        {EXTRAS.map(({ title, body }) => (
          <div key={title}>
            <dt>{title}</dt>
            <dd>{body}</dd>
          </div>
        ))}
      </dl>
    </Section>
  )
}
