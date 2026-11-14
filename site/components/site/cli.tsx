import { Bot } from "lucide-react"
import { CodeBlock } from "@/components/ui/code-block"
import { Tabs } from "@/components/ui/tabs"
import { CopyButton } from "@/components/site/copy-button"
import { InlineMd } from "@/components/site/inline-md"
import { Section } from "@/components/site/section"
import { GROUPS, SETTINGS, defaultLabel } from "@/data/settings"
import { BASE, INSTALL_CMD, REPO_URL, agentPrompt, cliFlags, type Table } from "@/lib/content"

function DocTable({ table, caption }: { table: Table; caption: string }) {
  return (
    <div className="table-scroll" role="region" aria-label={caption} tabIndex={0}>
      <table>
        <caption>{caption}</caption>
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
  const items = [
    {
      value: "install",
      label: "Install",
      body: (
        <div className="tab-body">
          <CodeBlock code={INSTALL_CMD} language="sh" label="Terminal" />
          <p>
            Checks your Mac, downloads the latest release, verifies its SHA-256 checksum and code signature, and installs
            ArcPatches.app. Files fetched with curl aren&rsquo;t quarantined, so macOS doesn&rsquo;t ask you to approve
            the app. <a href={`${REPO_URL}/blob/main/install.sh`}>Read the script</a>.
          </p>
        </div>
      ),
    },
    {
      value: "commands",
      label: "Commands",
      body: (
        <div className="tab-body">
          <CodeBlock code={BINARY} language="sh" label="The app is also a command line tool" />
          <DocTable table={cliFlags()} caption="ArcPatches flags" />
        </div>
      ),
    },
    {
      value: "settings",
      label: "Settings",
      body: (
        <div className="tab-body">
          <CodeBlock code={SETTINGS_EXAMPLE} language="sh" label="Terminal" />
          <p>
            Every setting with a picture of what it changes is on the <a href={`${BASE}/settings/`}>settings page</a>.
          </p>
          {GROUPS.map((g) => (
            <DocTable
              key={g.name}
              caption={g.name}
              table={{
                title: g.name,
                head: ["Key", "Type", "Default", "Setting"],
                rows: SETTINGS.filter((s) => s.group === g.name).map((s) => [
                  `\`${s.key}\``,
                  s.type,
                  defaultLabel(s),
                  s.title,
                ]),
              }}
            />
          ))}
        </div>
      ),
    },
    {
      value: "agent",
      label: "AI agent",
      body: (
        <div className="tab-body">
          <p>
            One prompt that has Claude Code, Cursor or Codex check your Mac, install ArcPatches, patch Dia and apply
            your settings. It asks before it quits Dia or removes anything, and never uses sudo.
          </p>
          <div className="cta-row">
            <CopyButton
              tone="primary"
              text={agentPrompt()}
              label="Copy agent prompt"
              done="Prompt copied"
              description="Paste it into your coding agent."
              icon={<Bot aria-hidden size={16} />}
            />
            <a className="pill-link" href={`${docs}/agent-install.md`}>
              Read the prompt
            </a>
          </div>
        </div>
      ),
    },
  ]
  return (
    <Section
      id="cli"
      eyebrow="Command line"
      title="Everything, from Terminal."
      intro={
        <>
          The full reference is in <a href={`${docs}/cli.md`}>docs/cli.md</a>; the tables below are built from it.
        </>
      }
    >
      <div className="glass cli">
        <Tabs items={items} label="Command line topics" />
      </div>
    </Section>
  )
}
