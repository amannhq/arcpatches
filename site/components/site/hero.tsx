import { Command, CopyLink } from "@/components/site/command"
import { PrintArt } from "@/components/site/print-art"
import { INSTALL_CMD, REPO_URL, agentPrompt, art, version } from "@/lib/content"

// A cover: a full-bleed illustration (site/art/hero.webp, or the procedural print when
// it's missing) with the text on a solid paper panel over it, so contrast never depends
// on the picture.
export function Hero() {
  const img = art("hero")
  return (
    <section id="top" className="hero" aria-labelledby="hero-title">
      <div className="hero-art" aria-hidden>
        {img ? (
          // eslint-disable-next-line @next/next/no-img-element -- static export
          <img src={img} alt="" fetchPriority="high" draggable={false} />
        ) : (
          <PrintArt />
        )}
      </div>
      <div className="wrap hero-wrap">
        <div className="hero-panel">
          <p className="label">ArcPatches {version()} · for Dia on macOS 14+</p>
          <h1 id="hero-title">Arc&rsquo;s sidebar, in Dia.</h1>
          <p className="lede">
            ArcPatches adds Arc&rsquo;s sidebar URL bar, ⌘T command bar and shortcuts to your copy of Dia. One click puts
            the original back.
          </p>
          <Command code={INSTALL_CMD} label="Install in Terminal" />
          <p className="hero-links">
            <a href={`${REPO_URL}/releases/latest`}>Download the app</a>
            <CopyLink text={agentPrompt()} label="Install with an agent" done="Agent prompt copied" />
            <a href={REPO_URL}>GitHub</a>
          </p>
        </div>
      </div>
    </section>
  )
}
