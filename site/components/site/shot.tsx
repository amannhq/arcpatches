import { DitherFrame } from "@/components/site/dither-frame"
import { shot } from "@/lib/content"

// A screenshot in a thin ink frame at its own aspect ratio, never taller than maxHeight,
// or an ASCII stand-in when docs/screenshots/<name>.png hasn't been rendered yet.
export function Shot({
  name,
  alt,
  priority = false,
  maxHeight = 620,
}: {
  name: string
  alt: string
  priority?: boolean
  maxHeight?: number
}) {
  const img = shot(name)
  if (!img) return <DitherFrame label={alt} />
  return (
    <figure className="shot" style={{ maxWidth: `${Math.round((maxHeight * img.width) / img.height)}px` }}>
      {/* eslint-disable-next-line @next/next/no-img-element -- static export, images are unoptimized anyway */}
      <img
        src={img.src}
        alt={alt}
        width={img.width}
        height={img.height}
        loading={priority ? "eager" : "lazy"}
        fetchPriority={priority ? "high" : undefined}
        decoding="async"
        draggable={false}
      />
    </figure>
  )
}
