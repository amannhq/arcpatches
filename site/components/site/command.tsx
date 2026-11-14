"use client"

import * as React from "react"
import { Check, Copy } from "lucide-react"

// A command in a plain monospace block with a small copy button. The block scrolls
// sideways when a line is longer than the screen (or wraps, with `wrap`); the page never does.
export function Command({ code, label, wrap = false }: { code: string; label?: string; wrap?: boolean }) {
  const [copied, setCopied] = React.useState(false)
  const copy = () => {
    navigator.clipboard.writeText(code).then(
      () => {
        setCopied(true)
        setTimeout(() => setCopied(false), 1600)
      },
      () => setCopied(false),
    )
  }
  return (
    <div className="command" data-wrap={wrap || undefined}>
      {label && <p className="command-label">{label}</p>}
      <div className="command-body">
        <pre tabIndex={0} aria-label={label ?? "Command"}>
          <code>{code.replace(/\n$/, "")}</code>
        </pre>
        <button type="button" className="command-copy" onClick={copy} aria-label={copied ? "Copied" : "Copy command"}>
          {copied ? <Check aria-hidden size={15} /> : <Copy aria-hidden size={15} />}
          <span aria-live="polite">{copied ? "Copied" : ""}</span>
        </button>
      </div>
    </div>
  )
}

// A text link that copies text instead of navigating, confirming in place.
export function CopyLink({ text, label, done = "Copied" }: { text: string; label: string; done?: string }) {
  const [copied, setCopied] = React.useState(false)
  return (
    <button
      type="button"
      className="text-link"
      onClick={() =>
        navigator.clipboard.writeText(text).then(() => {
          setCopied(true)
          setTimeout(() => setCopied(false), 1800)
        })
      }
    >
      <span aria-live="polite">{copied ? done : label}</span>
    </button>
  )
}
