import { RisoArt } from "@/components/site/riso-art"

// The quiet night scene fixed behind the whole page; sections and glass sit over it.
export function Backdrop() {
  return (
    <div className="backdrop" aria-hidden>
      <RisoArt variant="night" pixel={4} />
    </div>
  )
}
