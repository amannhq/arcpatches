import type { Metadata } from "next"
import { Backdrop } from "@/components/site/backdrop"
import { Footer } from "@/components/site/footer"
import { SiteNav } from "@/components/site/nav"
import { Section } from "@/components/site/section"
import { SettingsList } from "@/components/site/settings-list"
import { SETTINGS } from "@/data/settings"

export const metadata: Metadata = {
  title: "Settings · ArcPatches",
  description: "Every ArcPatches setting, what it changes, its default and the command to set it.",
}

export default function SettingsPage() {
  return (
    <>
      <Backdrop />
      <SiteNav current="settings" />
      <main id="main">
        <Section
          id="settings"
          eyebrow="Settings"
          title={`All ${SETTINGS.length} settings, shown.`}
          intro="Change them in Dia under Settings → ArcPatches, or from Terminal with Dia quit. Pick a state under each picture to see what it does and the command that sets it."
        >
          <SettingsList />
        </Section>
      </main>
      <Footer />
    </>
  )
}
