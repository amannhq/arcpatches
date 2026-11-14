import { BASE, REPO_URL } from "@/lib/content"

export function Footer() {
  return (
    <footer className="footer">
      <div className="wrap footer-inner">
        <p className="brand">ArcPatches</p>
        <nav aria-label="Footer">
          <a href={REPO_URL}>GitHub</a>
          <a href={`${REPO_URL}/releases`}>Releases</a>
          <a href={`${BASE}/settings/`}>Settings</a>
          <a href={`${REPO_URL}/blob/main/docs/cli.md`}>CLI reference</a>
          <a href={`${REPO_URL}/blob/main/SECURITY.md`}>Security</a>
          <a href={`${REPO_URL}/blob/main/CONTRIBUTING.md`}>Contributing</a>
        </nav>
        <p className="fine">
          Dia and Arc are trademarks of The Browser Company. <a href={`${REPO_URL}/blob/main/LICENSE`}>MIT license</a>.
        </p>
      </div>
    </footer>
  )
}
