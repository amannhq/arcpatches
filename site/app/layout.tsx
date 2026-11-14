import type { Metadata, Viewport } from "next"
import { GeistSans } from "geist/font/sans"
import { GeistMono } from "geist/font/mono"
import { Hardware } from "@/components/ui/hardware"
import { Toasts } from "@/components/ui/toaster"
import "./globals.css"

export const metadata: Metadata = {
  metadataBase: new URL("https://amannhq.github.io/arcpatches/"),
  title: "ArcPatches: Arc's sidebar, in Dia",
  description:
    "ArcPatches adds Arc's sidebar URL bar, ⌘T command bar and shortcuts to your copy of Dia. Open source, and one click restores the original.",
  openGraph: {
    title: "ArcPatches",
    description: "Arc's sidebar, in Dia.",
    url: "https://amannhq.github.io/arcpatches/",
    type: "website",
  },
}

export const viewport: Viewport = {
  themeColor: "#F4EFE6",
  colorScheme: "light",
}

// The kit's key colour is the print's teal-blue (#1F5F86), as OKLCH.
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${GeistSans.variable} ${GeistMono.variable}`}>
      <body>
        <Hardware className="ap" keyColor={{ l: 0.46, c: 0.09, h: 240 }}>
          {children}
          <Toasts />
        </Hardware>
      </body>
    </html>
  )
}
