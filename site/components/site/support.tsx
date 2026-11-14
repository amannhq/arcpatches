import { Section } from "@/components/site/section"
import { REPO_URL } from "@/lib/content"

type Status = "yes" | "partial" | "no" | "na"

const BROWSERS: { name: string; status: Status; label: string; note: string }[] = [
  { name: "Dia", status: "yes", label: "Supported", note: "Every feature. Tested on 1.57.x." },
  {
    name: "Ardia",
    status: "partial",
    label: "Partial",
    note: "Only the Chromium performance switches. Its UI is React Native, so it can't be patched like Dia's.",
  },
  { name: "Chrome", status: "no", label: "Not supported", note: "Its UI is drawn by Chromium's own C++ views." },
  { name: "Arc", status: "na", label: "Not a target", note: "Arc already has these features." },
]

export function Support() {
  return (
    <Section
      id="support"
      label="Browsers"
      title="Made for Dia."
      intro={
        <>
          Needs a Mac with Apple silicon, macOS 14 or later, and the browser in /Applications. Details per feature are in{" "}
          <a href={`${REPO_URL}/blob/main/docs/browsers.md`}>docs/browsers.md</a>.
        </>
      }
    >
      <div className="table-scroll" role="region" aria-label="Browser support" tabIndex={0}>
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
                  <span className="status" data-status={b.status}>
                    {b.label}
                  </span>
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
