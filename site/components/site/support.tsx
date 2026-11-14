import { Badge } from "@/components/ui/badge"
import { Section } from "@/components/site/section"
import { REPO_URL } from "@/lib/content"

const BROWSERS: { name: string; tone: "success" | "warning" | "danger" | "neutral"; status: string; note: string }[] = [
  { name: "Dia", tone: "success", status: "Supported", note: "Every feature. Tested on 1.57.x." },
  {
    name: "Ardia",
    tone: "warning",
    status: "Partial",
    note: "Only the Chromium performance switches. Its UI is React Native, so it can't be patched like Dia's.",
  },
  { name: "Chrome", tone: "danger", status: "Not supported", note: "Its UI is drawn by Chromium's own C++ views." },
  { name: "Arc", tone: "neutral", status: "Not a target", note: "Arc already is Arc, and it's being retired." },
]

export function Support() {
  return (
    <Section
      id="support"
      eyebrow="Browser support"
      title="Made for Dia."
      intro={
        <>
          Needs a Mac with Apple silicon, macOS 14 or later, and the browser in /Applications. Per-feature details are in{" "}
          <a href={`${REPO_URL}/blob/main/docs/browsers.md`}>docs/browsers.md</a>.
        </>
      }
    >
      <div className="glass table-scroll" role="region" aria-label="Browser support" tabIndex={0}>
        <table>
          <caption className="sr-only">Browser support</caption>
          <thead>
            <tr>
              <th scope="col">Browser</th>
              <th scope="col">Status</th>
              <th scope="col">Notes</th>
            </tr>
          </thead>
          <tbody>
            {BROWSERS.map((b) => (
              <tr key={b.name}>
                <th scope="row">{b.name}</th>
                <td>
                  <Badge tone={b.tone}>{b.status}</Badge>
                </td>
                <td>{b.note}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Section>
  )
}
