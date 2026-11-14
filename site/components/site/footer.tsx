import { GitHubMark } from "@/components/site/icons"
import { RisoArt } from "@/components/site/riso-art"
import { BASE, REPO_URL } from "@/lib/content"

export function Footer() {
  return (
    <footer className="footer">
      <div className="footer-art" aria-hidden>
        <RisoArt variant="dusk" />
      </div>
      <div className="wrap footer-inner glass">
        <div>
          <p className="footer-brand">ArcPatches</p>
          <p>
            Open source under the <a href={`${REPO_URL}/blob/main/LICENSE`}>MIT license</a>.
          </p>
          <p className="fine">
            Dia and Arc are trademarks of The Browser Company. ArcPatches is not affiliated with or endorsed by The
            Browser Company; the names are used only to say which browser it works with.
          </p>
        </div>
        <nav aria-label="Footer">
          <a href={REPO_URL}>
            <GitHubMark size={14} /> GitHub
          </a>
          <a href={`${REPO_URL}/releases`}>Releases</a>
          <a href={`${BASE}/settings/`}>Settings</a>
          <a href={`${REPO_URL}/blob/main/docs/cli.md`}>CLI reference</a>
          <a href={`${REPO_URL}/blob/main/SECURITY.md`}>Security</a>
          <a href={`${REPO_URL}/blob/main/CONTRIBUTING.md`}>Contributing</a>
        </nav>
      </div>
    </footer>
  )
}
