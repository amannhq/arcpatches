import { Display } from "@/components/ui/display"
import { RisoArt } from "@/components/site/riso-art"
import { shot } from "@/lib/content"

// A screenshot on the kit's display at its own aspect ratio, never taller than maxHeight,
// or a dithered stand-in labelled with the feature when docs/screenshots/<name>.png
// hasn't been rendered yet.
export function Shot({
  name,
  alt,
  priority = false,
  maxHeight = 560,
}: {
  name: string
  alt: string
  priority?: boolean
  maxHeight?: number
}) {
  const img = shot(name)
  if (!img) {
    return (
      <Display aspect="16 / 10">
        <div data-shot-placeholder role="img" aria-label={`${alt} (screenshot coming soon)`}>
          <RisoArt variant="frame" pixel={2} />
          <span aria-hidden>{alt}</span>
        </div>
      </Display>
    )
  }
  return (
    <div className="shot" style={{ maxWidth: `${Math.round((maxHeight * img.width) / img.height)}px` }}>
      <Display aspect={`${img.width} / ${img.height}`}>
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
      </Display>
    </div>
  )
}
