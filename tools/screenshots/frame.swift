// Dev tool: places shots.m's renders, as glass panels, on backdrop.swift's poster art.
//   swiftc -O -parse-as-library tools/screenshots/frame.swift tools/screenshots/backdrop.swift -o build/frame
//   build/frame <raw-dir> <out-dir>
// Reads the 2x renders in <raw-dir>; writes hero, sidebar, pill-hover, site-controls,
// palette and editor PNGs (2x, opaque RGB) to <out-dir>.
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }

/// The backdrop and its frosted copy for the image being drawn.
struct Canvas {
    let backdrop: CGImage, frosted: CGImage

    init(pixels w: Int, _ h: Int, scene: Scene) {
        backdrop = makeBackdrop(width: w, height: h, scene: scene)
        frosted = frost(backdrop, sigma: 72)   // ~36 pt at 2x
    }
}

var canvas: Canvas!
var raw: URL!, out: URL!

func load(_ name: String) -> NSImage {
    let img = NSImage(contentsOf: raw.appendingPathComponent(name))!
    let rep = img.representations[0]
    img.size = NSSize(width: CGFloat(rep.pixelsWide) / 2, height: CGFloat(rep.pixelsHigh) / 2)   // back to points
    return img
}

/// A glass panel: shadow, the frosted backdrop clipped to the panel, an optional tint,
/// `content`, then a 1-px inner highlight.
func glass(_ frame: NSRect, radius: CGFloat, tint: NSColor? = nil, _ content: () -> Void) {
    let shape = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
    let cg = NSGraphicsContext.current!.cgContext
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = rgb(0.02, 0.05, 0.07, 0.6); sh.shadowBlurRadius = 44; sh.shadowOffset = NSSize(width: 0, height: -20); sh.set()
    rgb(0.05, 0.06, 0.07).setFill(); shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    let full = NSRect(x: 0, y: 0, width: CGFloat(canvas.frosted.width) / 2, height: CGFloat(canvas.frosted.height) / 2)
    cg.draw(canvas.frosted, in: full)
    if let tint { tint.setFill(); frame.fill(using: .sourceOver) }
    content()
    NSGraphicsContext.restoreGraphicsState()
    let edge = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: radius - 0.5, yRadius: radius - 0.5)
    rgb(1, 1, 1, 0.12).setStroke(); edge.lineWidth = 1; edge.stroke()
}

/// A render as a glass panel; the render carries its own translucent tint.
func panel(_ img: NSImage, at origin: NSPoint, radius: CGFloat = 14) {
    let frame = NSRect(origin: origin, size: img.size)
    glass(frame, radius: radius) { img.draw(in: frame) }
}

func caption(_ text: String, at p: NSPoint) {
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: rgb(1, 1, 1, 0.72)]
    (text as NSString).draw(at: p, withAttributes: a)
}

func render(size: NSSize, to name: String, scene: Scene, _ draw: (NSRect) -> Void) {
    let w = Int(size.width * 2), h = Int(size.height * 2)
    canvas = Canvas(pixels: w, h, scene: scene)
    let cg = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    cg.draw(canvas.backdrop, in: CGRect(x: 0, y: 0, width: w, height: h))
    cg.scaleBy(x: 2, y: 2)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
    draw(NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    let url = out.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    posterise(cg)
    CGImageDestinationAddImage(dest, cg.makeImage()!, [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144] as CFDictionary)
    CGImageDestinationFinalize(dest)
    print("wrote", url.path)
}

/// One render centred on its own scene.
func single(_ name: String, scene: Scene, pad: CGFloat = 72, radius: CGFloat = 14) {
    let img = load(name)
    render(size: NSSize(width: img.size.width + pad * 2, height: img.size.height + pad * 2), to: name, scene: scene) { _ in
        panel(img, at: NSPoint(x: pad, y: pad + 6), radius: radius)
    }
}

@main
struct Frame {
    static func main() {
        raw = URL(fileURLWithPath: CommandLine.arguments[1]); out = URL(fileURLWithPath: CommandLine.arguments[2])
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        // 1. Hero: the sidebar, with the ⌘T palette beside it at the height Arc puts it.
        let sidebar = load("sidebar.png"), palette = load("palette.png")
        let gap: CGFloat = 48, pad: CGFloat = 64
        let heroSize = NSSize(width: pad * 2 + sidebar.size.width + gap + palette.size.width, height: pad * 2 + sidebar.size.height)
        render(size: heroSize, to: "hero.png", scene: Scene(seed: 11, sun: (0.80, 0.30, 0.20))) { r in
            panel(sidebar, at: NSPoint(x: pad, y: pad), radius: 12)
            let top = r.maxY - pad - sidebar.size.height * 0.30
            panel(palette, at: NSPoint(x: pad + sidebar.size.width + gap, y: top - palette.size.height))
        }

        // 2. Single renders, each on its own seed of the same landscape.
        single("sidebar.png", scene: Scene(seed: 23, sun: (0.72, 0.22, 0.13)), radius: 12)
        single("site-controls.png", scene: Scene(seed: 5, sun: (0.25, 0.20, 0.14)))
        single("palette.png", scene: Scene(seed: 41, sun: (0.15, 0.34, 0.26)))
        single("editor.png", scene: Scene(seed: 8, sun: (0.84, 0.30, 0.22)))

        // 3. The URL pill at rest, under the pointer, and with no page open, on one glass strip.
        let states = [("At rest", load("pill-rest.png")), ("Hover: copy link and site controls", load("pill-hover.png")),
                      ("No page open", load("pill-empty.png"))]
        let pillW = states[0].1.size.width, rowH = states[0].1.size.height + 24
        let strip = NSSize(width: pillW, height: rowH * CGFloat(states.count) + 12)
        render(size: NSSize(width: strip.width + 144, height: strip.height + 144), to: "pill-hover.png",
               scene: Scene(seed: 17, sun: (0.78, 0.24, 0.16))) { _ in
            let frame = NSRect(x: 72, y: 72, width: strip.width, height: strip.height)
            glass(frame, radius: 12, tint: rgb(0.07, 0.08, 0.09, 0.62)) {
                var y = frame.maxY - 6
                for (label, img) in states {
                    y -= rowH
                    caption(label, at: NSPoint(x: frame.minX + 12, y: y + img.size.height + 4))
                    img.draw(in: NSRect(x: frame.minX, y: y, width: img.size.width, height: img.size.height))
                }
            }
        }
    }
}
