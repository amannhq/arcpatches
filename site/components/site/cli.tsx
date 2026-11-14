import { Command, CopyLink } from "@/components/site/command"
import { InlineMd } from "@/components/site/inline-md"
import { Section } from "@/components/site/section"
import { AGENT_DOC_URL, BASE, REPO_URL, agentPrompt, cliFlags, type Table } from "@/lib/content"

export function DocTable({ table, caption }: { table: Table; caption: string }) {
  return (
    <div className="table-scroll" role="region" aria-label={caption} tabIndex={0}>
      <table>
        <caption className="sr-only">{caption}</caption>
        <thead>
          <tr>
            {table.head.map((h) => (
              <th key={h} scope="col">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {table.rows.map((row) => (
            <tr key={row[0]}>
              {row.map((cell, i) =>
                i === 0 ? (
                  <th key={i} scope="row">
                    <InlineMd text={cell} />
                  </th>
                ) : (
                  <td key={i}>
                    <InlineMd text={cell} />
                  </td>
                ),
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

const BINARY = `AP=/Applications/ArcPatches.app/Contents/MacOS/ArcPatches
"$AP" --status     # what's patched, and whether Dia is running
"$AP" --patch      # quit Dia first
"$AP" --restore    # put the original Dia back`

const SETTINGS_EXAMPLE = `# Quit Dia first. Keys live in Dia's own preferences.
defaults write company.thebrowser.dia arcpatches.blockTelemetry -bool YES
defaults write company.thebrowser.dia arcpatches.urlBarMode -int 2
defaults delete company.thebrowser.dia arcpatches.blockTelemetry   # back to default`

export function Cli() {
  const docs = `${REPO_URL}/blob/main/docs`
  return (
    <Section
      id="cli"
      label="Command line"
      title="Everything works from Terminal."
      intro={
        <>
          The full reference is <a href={`${docs}/cli.md`}>docs/cli.md</a>. The flags table below is built from it.
        </>
      }
    >
      <div className="cli">
        <div className="cli-block">
          <h3>The install script</h3>
          <p>
            It checks your Mac, downloads the latest release, verifies its SHA-256 checksum and code signature, and
            installs ArcPatches.app. Files fetched with curl aren&rsquo;t quarantined, so macOS doesn&rsquo;t ask you to
            approve the app. <a href={`${REPO_URL}/blob/main/install.sh`}>Read the script</a>.
          </p>
        </div>
        <div className="cli-block">
          <h3>The app is also a command line tool</h3>
          <Command code={BINARY} label="Terminal" />
          <DocTable table={cliFlags()} caption="ArcPatches flags" />
        </div>
        <div className="cli-block">
          <h3>Settings</h3>
          <Command code={SETTINGS_EXAMPLE} label="Terminal" />
          <p>
            Every key, with pictures of what it changes, is on the <a href={`${BASE}/settings/`}>settings page</a>.
          </p>
        </div>
        <div className="cli-block">
          <h3>With a coding agent</h3>
          <p>
            One prompt has Claude Code, Cursor or Codex check your Mac, install ArcPatches, patch Dia and apply your
            settings. It asks before it quits Dia or removes anything, and never uses sudo.
          </p>
          <p className="hero-links">
            <CopyLink text={agentPrompt()} label="Copy the prompt" done="Prompt copied" />
            <a href={AGENT_DOC_URL}>Read it first</a>
          </p>
        </div>
      </div>
    </Section>
  )
}
