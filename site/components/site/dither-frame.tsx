import type * as React from "react"
import { asciiFrame, seedOf } from "@/lib/ascii"

// A stand-in for a screenshot that hasn't been rendered yet: an ASCII browser window over
// a dithered field, printed on the server, with the feature's name under it.
export function DitherFrame({ label, cols = 72, rows = 24 }: { label: string; cols?: number; rows?: number }) {
  return (
    <div className="dither-frame" role="img" aria-label={`${label} (screenshot coming)`}>
      <pre aria-hidden style={{ "--cols": cols } as React.CSSProperties}>
        {asciiFrame(cols, rows, seedOf(label))}
      </pre>
      <span aria-hidden>{label}</span>
    </div>
  )
}
