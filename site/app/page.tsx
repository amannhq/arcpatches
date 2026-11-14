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
import { BASE, art } from "@/lib/content"

export default function Home() {
  // An optional second illustration (site/art/hero-2.webp); nothing is drawn without it.
  const band = art("hero-2")
  return (
    <>
      <SiteNav current="home" />
      <main id="main">
        <Hero />
        <Features />
        {band && (
          <div className="art-band" aria-hidden>
            {/* eslint-disable-next-line @next/next/no-img-element -- static export */}
            <img src={band} alt="" loading="lazy" draggable={false} />
          </div>
        )}
        <How />
        <Section
          id="settings-teaser"
          label="Settings"
          title="Set it up your way."
          intro={`${SETTINGS.length} settings in ${GROUPS.length} groups. Each one is shown on and off, with the command that sets it.`}
        >
          <dl className="ruled-grid">
            {GROUPS.map((g) => (
              <div key={g.name}>
                <dt>{g.name}</dt>
                <dd>{g.blurb}</dd>
              </div>
            ))}
          </dl>
          <p className="more">
            <a href={`${BASE}/settings/`}>See every setting →</a>
          </p>
        </Section>
        <Cli />
        <Support />
        <Faq />
      </main>
      <Footer />
    </>
  )
}
