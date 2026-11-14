import { ArrowUpRight, Bot } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { CodeBlock } from "@/components/ui/code-block"
import { Lcd, LcdDigits } from "@/components/ui/lcd"
import { CopyButton } from "@/components/site/copy-button"
import { GitHubMark } from "@/components/site/icons"
import { RisoArt } from "@/components/site/riso-art"
import { Shot } from "@/components/site/shot"
import { INSTALL_CMD, REPO_URL, agentPrompt, version } from "@/lib/content"

export function Hero() {
  const v = version()
  return (
    <section id="top" className="hero" aria-labelledby="hero-title">
      <div className="hero-art" aria-hidden>
        <RisoArt variant="hero" />
      </div>
      <div className="wrap hero-grid">
        <div className="glass hero-copy">
          <Badge tone="warning">Unofficial · Open source · MIT</Badge>
          <h1 id="hero-title">Arc&rsquo;s sidebar, back in your browser.</h1>
          <p className="lede">
            ArcPatches patches your own copy of Dia with the parts of Arc you miss: the URL bar in the sidebar, the
            ⌘T command bar, full-window pages and Arc&rsquo;s shortcuts. The original comes back in one click.
          </p>
          <CodeBlock code={INSTALL_CMD} language="sh" label="Install in Terminal" />
          <div className="cta-row">
            <CopyButton
              tone="primary"
              text={INSTALL_CMD}
              label="Copy install command"
              description="Paste it into Terminal, then quit Dia and click Patch."
            />
            <CopyButton
              text={agentPrompt()}
              label="Install with your AI agent"
              done="Prompt copied"
              description="Paste it into Claude Code, Cursor or Codex."
              icon={<Bot aria-hidden size={16} />}
            />
          </div>
          <div className="hero-meta">
            <a className="pill-link" href={REPO_URL}>
              <GitHubMark size={16} /> amannhq/arcpatches
            </a>
            <a className="pill-link" href={`${REPO_URL}/releases/latest`} aria-label={`Latest release, version ${v}`}>
              <Lcd tag="release" size="sm">
                <LcdDigits value={v} />
              </Lcd>
              <ArrowUpRight aria-hidden size={14} />
            </a>
          </div>
          <p className="fine">macOS 14 or later · Apple silicon · Tested on Dia 1.57</p>
        </div>
        <div className="hero-shot">
          <Shot name="hero" alt="Dia with ArcPatches: the URL bar and navigation in the sidebar" priority />
        </div>
      </div>
    </section>
  )
}
