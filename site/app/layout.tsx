import type { Metadata, Viewport } from "next"
import { GeistSans } from "geist/font/sans"
import { GeistMono } from "geist/font/mono"
import { Hardware } from "@/components/ui/hardware"
import { Toasts } from "@/components/ui/toaster"
import "./globals.css"

export const metadata: Metadata = {
  metadataBase: new URL("https://amannhq.github.io/arcpatches/"),
  title: "ArcPatches: Arc's sidebar, back in your browser",
  description:
    "ArcPatches patches your own copy of Dia with Arc's sidebar URL bar, ⌘T command bar and shortcuts. Open source, restorable in one click.",
  openGraph: {
    title: "ArcPatches",
    description: "Arc's sidebar, back in your browser.",
    url: "https://amannhq.github.io/arcpatches/",
    type: "website",
  },
}

export const viewport: Viewport = {
  themeColor: "#0E3A48",
  colorScheme: "dark",
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${GeistSans.variable} ${GeistMono.variable}`}>
      <body>
        <Hardware className="ap" keyColor={{ l: 0.82, c: 0.16, h: 78 }}>
          {children}
          <Toasts />
        </Hardware>
      </body>
    </html>
  )
}
