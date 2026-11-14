"use client"

import * as React from "react"
import { Volume2, VolumeX } from "lucide-react"
import { onSoundChange, setSoundEnabled, soundEnabled } from "@/lib/sound"

// The kit plays a soft click on key presses; this lets visitors turn that off.
export function SoundToggle() {
  const [on, setOn] = React.useState(true)
  React.useEffect(() => {
    setOn(soundEnabled())
    return onSoundChange(setOn)
  }, [])
  return (
    <button
      type="button"
      data-icon-button
      aria-pressed={on}
      aria-label={on ? "Turn key sounds off" : "Turn key sounds on"}
      title={on ? "Key sounds on" : "Key sounds off"}
      onClick={() => setSoundEnabled(!on)}
    >
      {on ? <Volume2 aria-hidden size={18} /> : <VolumeX aria-hidden size={18} />}
    </button>
  )
}
