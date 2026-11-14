import * as React from "react"
import { REPO_URL } from "@/lib/content"

// Just enough inline Markdown for the doc tables: `code`, **bold** and [links](url).
// Relative links point at the docs on GitHub.
export function InlineMd({ text }: { text: string }) {
  const parts = text.split(/(`[^`]+`|\*\*[^*]+\*\*|\[[^\]]+\]\([^)]+\))/g)
  return (
    <>
      {parts.map((p, i) => {
        if (p.startsWith("`")) return <code key={i}>{p.slice(1, -1)}</code>
        if (p.startsWith("**")) return <strong key={i}>{p.slice(2, -2)}</strong>
        const link = p.match(/^\[([^\]]+)\]\(([^)]+)\)$/)
        if (link) {
          const target = link[2]
          const href = /^https?:/.test(target)
            ? target
            : `${REPO_URL}/blob/main/${target.startsWith("../") ? target.slice(3) : `docs/${target}`}`
          return (
            <a key={i} href={href}>
              {link[1]}
            </a>
          )
        }
        return <React.Fragment key={i}>{p}</React.Fragment>
      })}
    </>
  )
}
