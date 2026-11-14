import { Navbar } from "@/components/ui/navbar"
import { GitHubMark } from "@/components/site/icons"
import { SoundToggle } from "@/components/site/sound-toggle"
import { BASE, REPO_URL } from "@/lib/content"

// Links are absolute (with the base path) so they work from every page.
export function SiteNav({ current }: { current: "home" | "settings" }) {
  const home = `${BASE}/`
  const items = [
    { href: `${home}#features`, label: "Features" },
    { href: `${home}#how`, label: "How it works" },
    { href: `${BASE}/settings/`, label: "Settings", current: current === "settings" },
    { href: `${home}#cli`, label: "CLI" },
    { href: `${home}#faq`, label: "FAQ" },
  ]
  return (
    <div className="site-nav">
      <a className="skip" href="#main">
        Skip to content
      </a>
      <Navbar brand={{ href: home, name: "ArcPatches" }} label="Site" items={items}>
        <div className="nav-tools">
          <SoundToggle />
          <a data-icon-button href={REPO_URL} aria-label="ArcPatches on GitHub">
            <GitHubMark />
          </a>
        </div>
      </Navbar>
    </div>
  )
}
