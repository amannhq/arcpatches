import { BASE, REPO_URL } from "@/lib/content"

// A plain masthead: the name, a few links, a rule. Links carry the base path so they
// work from every page.
export function SiteNav({ current }: { current: "home" | "settings" }) {
  const home = `${BASE}/`
  const items = [
    { href: `${home}#features`, label: "Features" },
    { href: `${home}#how`, label: "How it works" },
    { href: `${BASE}/settings/`, label: "Settings", current: current === "settings" },
    { href: `${home}#cli`, label: "Command line" },
    { href: `${home}#faq`, label: "FAQ" },
  ]
  return (
    <header className="masthead">
      <a className="skip" href="#main">
        Skip to content
      </a>
      <div className="wrap masthead-inner">
        <a className="brand" href={home}>
          ArcPatches
        </a>
        <nav aria-label="Site">
          {items.map((i) => (
            <a key={i.label} href={i.href} aria-current={i.current ? "page" : undefined}>
              {i.label}
            </a>
          ))}
          <a href={REPO_URL}>GitHub</a>
        </nav>
      </div>
    </header>
  )
}
