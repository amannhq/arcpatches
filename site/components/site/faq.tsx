import * as React from "react"
import { Section } from "@/components/site/section"
import { REPO_URL } from "@/lib/content"

const FAQ: { q: string; a: React.ReactNode }[] = [
  {
    q: "Why isn't ArcPatches notarized?",
    a: (
      <>
        Notarization needs a paid Apple developer account, which this project doesn&rsquo;t have yet. Releases are built by
        GitHub Actions from this repository, and ArcPatches&rsquo; own updates are verified with an ed25519 signature. The
        install script checks the download&rsquo;s SHA-256 checksum and code signature before installing.
      </>
    ),
  },
  {
    q: "macOS says it can't open ArcPatches. What do I do?",
    a: (
      <>
        That happens when the app was downloaded in a browser. Open System Settings → Privacy &amp; Security, scroll down,
        and click <strong>Open Anyway</strong> next to ArcPatches. Or install with the curl command: files fetched with curl
        aren&rsquo;t quarantined, so macOS doesn&rsquo;t ask.
      </>
    ),
  },
  {
    q: "Is it safe?",
    a: (
      <>
        The code is open, and the patch only adds a small library to your own copy of Dia. The hardened runtime stays on:
        only library validation is relaxed so the library can load, and DYLD_INSERT_LIBRARIES stays blocked. Because the
        patched app is signed on your Mac, macOS asks once for &ldquo;Dia Safe Storage&rdquo;; choose Always Allow. Passkeys
        from Apple Passwords only work in the vendor-signed app. Read{" "}
        <a href={`${REPO_URL}#security-and-trade-offs`}>Security and trade-offs</a> before installing.
      </>
    ),
  },
  {
    q: "What happens when Dia updates?",
    a: "Dia's own updater keeps working. After it installs a new version, ArcPatches patches it again, from its menu bar app or a background job. If an update changes something a feature depends on, that feature turns itself off rather than crashing, and the app lists which one.",
  },
  {
    q: "How do I undo it?",
    a: (
      <>
        Click <strong>Restore Original Dia</strong> in ArcPatches, or run <code>ArcPatches --restore</code> with Dia quit.
        To remove ArcPatches entirely, follow the uninstall steps in{" "}
        <a href={`${REPO_URL}/blob/main/docs/cli.md#uninstall`}>docs/cli.md</a>.
      </>
    ),
  },
]

export function Faq() {
  return (
    <Section id="faq" label="FAQ" title="Questions">
      <div className="faq">
        {FAQ.map(({ q, a }) => (
          <details key={q}>
            <summary>{q}</summary>
            <div className="answer">
              <p>{a}</p>
            </div>
          </details>
        ))}
      </div>
    </Section>
  )
}
