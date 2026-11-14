import { EyeOff, Keyboard, Maximize2, RefreshCw } from "lucide-react"
import { Card } from "@/components/ui/card"
import { Section } from "@/components/site/section"
import { Shot } from "@/components/site/shot"

const SHOWCASE = [
  {
    shot: "sidebar",
    title: "Sidebar URL bar",
    body: "The current site sits at the top of the sidebar, with back, forward and reload beside the window buttons and a sidebar toggle after them.",
    alt: "The sidebar with the URL pill and navigation buttons",
  },
  {
    shot: "pill-hover",
    title: "Tools when you need them",
    body: "Hover the URL pill and copy-link and site-controls buttons fade in at its edge. Move away and they're gone.",
    alt: "The URL pill with its hover buttons showing",
  },
  {
    shot: "site-controls",
    title: "Site controls",
    body: "Actions, extensions, permissions and the connection's security in one popover, in Arc's order.",
    alt: "The site controls popover",
  },
  {
    shot: "palette",
    title: "⌘T command bar",
    body: "Search open tabs, history and bookmarks, run browser commands, open chrome:// pages, and let sites complete as you type.",
    alt: "The ⌘T command bar over a page",
  },
  {
    shot: "editor",
    title: "⌘L address editor",
    body: "Drops down over the pill with the full URL selected, then the current page, the site's root and related history.",
    alt: "The ⌘L address editor below the URL pill",
  },
]

const EXTRAS = [
  {
    icon: Maximize2,
    title: "Full-window pages",
    body: "The top toolbar is gone, so pages use the whole window. Hover the top edge to bring it back.",
  },
  {
    icon: Keyboard,
    title: "Arc shortcuts",
    body: "⌘S toggles the sidebar, ⌘⇧C copies a clean URL, ⌘⇧⌥C copies a Markdown link. Each can be turned off.",
  },
  {
    icon: EyeOff,
    title: "AI out of the way",
    body: "Hides chat entry points and stops the on-device model. Can block AI and telemetry hosts too.",
  },
  {
    icon: RefreshCw,
    title: "Stays patched",
    body: "The menu bar app patches Dia again after each update, and restores the original in one click.",
  },
]

export function Features() {
  return (
    <Section
      id="features"
      eyebrow="Features"
      title="The Arc parts Dia left out."
      intro="Everything is drawn natively, in Arc's measurements, and every feature can be switched off in Settings → ArcPatches."
    >
      <ol className="showcase">
        {SHOWCASE.map((f, i) => (
          <li key={f.shot} className="glass showcase-item" data-flip={i % 2 === 1 || undefined}>
            <div className="showcase-text">
              <span className="index" aria-hidden>
                {String(i + 1).padStart(2, "0")}
              </span>
              <h3>{f.title}</h3>
              <p>{f.body}</p>
            </div>
            <Shot name={f.shot} alt={f.alt} />
          </li>
        ))}
      </ol>
      <div className="extras">
        {EXTRAS.map(({ icon: Icon, title, body }) => (
          <Card key={title} title={title} action={<Icon aria-hidden size={20} className="card-icon" />}>
            <p>{body}</p>
          </Card>
        ))}
      </div>
    </Section>
  )
}
