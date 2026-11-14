"use client"

import * as React from "react"
import { Check, Copy } from "lucide-react"
import { Button } from "@/components/ui/button"
import { notify } from "@/components/ui/toaster"

// A kit key that copies text, confirming in place and with a toast.
export function CopyButton({
  text,
  label,
  done = "Copied",
  description,
  tone = "secondary",
  icon,
}: {
  text: string
  label: string
  done?: string
  description?: string
  tone?: "primary" | "secondary"
  icon?: React.ReactNode
}) {
  const [copied, setCopied] = React.useState(false)
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      notify(done, description ? { description } : undefined)
      setTimeout(() => setCopied(false), 1600)
    } catch {
      notify("Couldn't copy", { description: "Your browser blocked the clipboard. Select the text and copy it instead." })
    }
  }
  return (
    <Button tone={tone} onClick={copy} data-copy aria-live="polite">
      {copied ? <Check aria-hidden size={16} /> : (icon ?? <Copy aria-hidden size={16} />)}
      <span>{copied ? done : label}</span>
    </Button>
  )
}
