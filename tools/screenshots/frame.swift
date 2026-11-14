// Dev tool: places shots.m's renders on a styled backdrop for the README.
//   swift tools/screenshots/frame.swift <raw-dir> <out-dir>
// Reads the 2x renders in <raw-dir>; writes hero, sidebar, pill-hover, site-controls,
// palette and editor PNGs (2x) to <out-dir>.
import AppKit

let raw = URL(fileURLWithPath: CommandLine.arguments[1]), out = URL(fileURLWithPath: CommandLine.arguments[2])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }

func load(_ name: String) -> NSImage {
    let img = NSImage(contentsOf: raw.appendingPathComponent(name))!
    let rep = img.representations[0]
    img.size = NSSize(width: CGFloat(rep.pixelsWide) / 2, height: CGFloat(rep.pixelsHigh) / 2)   // back to points
    return img
}

var currentRep: NSBitmapImageRep!

/// Warm near-black with soft amber glows, computed per pixel into the bitmap. Core
/// Graphics dithers its gradients, and that noise made every PNG several times larger.
func drawBackground(_ r: NSRect) {
    NSGraphicsContext.current?.flushGraphics()
    let rep = currentRep!, w = rep.pixelsWide, h = rep.pixelsHigh, bpr = rep.bytesPerRow, data = rep.bitmapData!
    let span = CGFloat(max(w, h))
    // (colour, centre x, centre y from the bottom, radius, strength), added like light.
    let glows: [([CGFloat], CGFloat, CGFloat, CGFloat, CGFloat)] = [
        ([1.00, 0.70, 0.02], 0.12, 1.04, 0.45, 0.85),   // yellow, rising at the top left
        ([1.00, 0.45, 0.05], 0.98, -0.04, 0.45, 0.65),  // amber, bottom right
    ]
    func falloff(_ d: CGFloat) -> CGFloat {   // 1 at the centre, 0.35 at 45%, 0 at the edge
        d >= 1 ? 0 : d < 0.45 ? 1 - 0.65 * d / 0.45 : 0.35 * (1 - (d - 0.45) / 0.55)
    }
    for j in 0..<h {
        let y = 1 - CGFloat(j) / CGFloat(h)
        for i in 0..<w {
            let x = CGFloat(i) / CGFloat(w)
            let t = min(1, max(0, (x + (1 - y)) / 2))   // top left to bottom right
            let base: CGFloat = t < 0.5 ? 0.08 + 0.04 * t : 0.10 - 0.08 * (t - 0.5)
            var c = [base, base * 0.95, base * 0.85]
            for g in glows {
                let dx = (x - g.1) * CGFloat(w), dy = (y - g.2) * CGFloat(h)
                let k = falloff((dx * dx + dy * dy).squareRoot() / (g.3 * span)) * g.4
                for n in 0..<3 { c[n] += g.0[n] * k }
            }
            let p = data + j * bpr + i * 4
            for n in 0..<3 { p[n] = UInt8(min(255, (c[n] * 255).rounded())) }
            p[3] = 255
        }
    }
}

/// A render with a soft shadow; its own corners are already drawn by shots.m.
@discardableResult
func drawCard(_ img: NSImage, at origin: NSPoint, radius: CGFloat = 14) -> NSRect {
    let frame = NSRect(origin: origin, size: img.size)
    let shape = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = rgb(0, 0, 0, 0.55); sh.shadowBlurRadius = 40; sh.shadowOffset = NSSize(width: 0, height: -18); sh.set()
    rgb(0.12, 0.12, 0.13).setFill(); shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState(); shape.addClip()
    img.draw(in: frame)
    NSGraphicsContext.restoreGraphicsState()
    rgb(1, 1, 1, 0.10).setStroke(); shape.lineWidth = 1; shape.stroke()
    return frame
}

func caption(_ text: String, at p: NSPoint) {
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: rgb(1, 1, 1, 0.58)]
    (text as NSString).draw(at: p, withAttributes: a)
}

func render(size: NSSize, to name: String, _ draw: (NSRect) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    currentRep = rep
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
    print("wrote", out.appendingPathComponent(name).path)
}

/// One render centred on the backdrop.
func single(_ name: String, pad: CGFloat = 64, radius: CGFloat = 14) {
    let img = load(name)
    render(size: NSSize(width: img.size.width + pad * 2, height: img.size.height + pad * 2), to: name) { r in
        drawBackground(r)
        drawCard(img, at: NSPoint(x: pad, y: pad + 6), radius: radius)
    }
}

// 1. Hero: the sidebar, with the ⌘T palette beside it at the height Arc puts it.
let sidebar = load("sidebar.png"), palette = load("palette.png")
let gap: CGFloat = 44, pad: CGFloat = 56
let heroSize = NSSize(width: pad * 2 + sidebar.size.width + gap + palette.size.width, height: pad * 2 + sidebar.size.height)
render(size: heroSize, to: "hero.png") { r in
    drawBackground(r)
    drawCard(sidebar, at: NSPoint(x: pad, y: pad), radius: 12)
    let top = r.maxY - pad - sidebar.size.height * 0.18
    drawCard(palette, at: NSPoint(x: pad + sidebar.size.width + gap, y: top - palette.size.height))
}

// 2. Single renders.
single("sidebar.png", radius: 12)
single("site-controls.png")
single("palette.png")
single("editor.png")

// 3. The URL pill at rest, under the pointer, and with no page open.
let states = [("At rest", load("pill-rest.png")), ("Hover: copy link and site controls", load("pill-hover.png")),
              ("No page open", load("pill-empty.png"))]
let pillW = states[0].1.size.width, rowH = states[0].1.size.height + 24
let panel = NSSize(width: pillW, height: rowH * CGFloat(states.count) + 12)
render(size: NSSize(width: panel.width + 128, height: panel.height + 128), to: "pill-hover.png") { r in
    drawBackground(r)
    let frame = NSRect(x: 64, y: 64, width: panel.width, height: panel.height)
    let shape = NSBezierPath(roundedRect: frame, xRadius: 12, yRadius: 12)
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = rgb(0, 0, 0, 0.55); sh.shadowBlurRadius = 40; sh.shadowOffset = NSSize(width: 0, height: -18); sh.set()
    rgb(0.135, 0.135, 0.145).setFill(); shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    rgb(1, 1, 1, 0.10).setStroke(); shape.lineWidth = 1; shape.stroke()
    var y = frame.maxY - 6
    for (label, img) in states {
        y -= rowH
        caption(label, at: NSPoint(x: frame.minX + 12, y: y + img.size.height + 4))
        img.draw(in: NSRect(x: frame.minX, y: y, width: img.size.width, height: img.size.height))
    }
}
