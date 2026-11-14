import { ArrowRight } from "lucide-react"
import { Backdrop } from "@/components/site/backdrop"
import { Cli } from "@/components/site/cli"
import { Faq } from "@/components/site/faq"
import { Features } from "@/components/site/features"
import { Footer } from "@/components/site/footer"
import { Hero } from "@/components/site/hero"
import { How } from "@/components/site/how"
import { SiteNav } from "@/components/site/nav"
import { Section } from "@/components/site/section"
import { Support } from "@/components/site/support"
import { GROUPS, SETTINGS } from "@/data/settings"
import { BASE } from "@/lib/content"

export default function Home() {
  return (
    <>
      <Backdrop />
      <SiteNav current="home" />
      <main id="main">
        <Hero />
        <Features />
        <How />
        <Section
          id="settings-teaser"
          eyebrow="Settings"
          title="Make it yours."
          intro={`${SETTINGS.length} settings in ${GROUPS.length} groups, each shown on and off with the command that sets it.`}
        >
          <div className="glass teaser">
            <ul>
              {GROUPS.map((g) => (
                <li key={g.name}>
                  <strong>{g.name}</strong> <span>{g.blurb}</span>
                </li>
              ))}
            </ul>
            <a className="pill-link strong" href={`${BASE}/settings/`}>
              See every setting <ArrowRight aria-hidden size={16} />
            </a>
          </div>
        </Section>
        <Cli />
        <Support />
        <Faq />
      </main>
      <Footer />
    </>
  )
}
