// ArcPatches icons, drawn in code.
//  - App icon: a browser window with a sidebar, white on an indigo-to-coral tile.
//  - Menu bar: the same window-and-sidebar glyph as a template image.
import AppKit

enum ArcPatchesIcon {
    enum Badge { case none, busy, attention }

    /// Window outline with a filled sidebar on the left, in the current colour.
    static func drawGlyph(in rect: NSRect, lineWidth: CGFloat) {
        let s = min(rect.width, rect.height)
        let frame = NSRect(x: rect.midX - s * 0.44, y: rect.midY - s * 0.34, width: s * 0.88, height: s * 0.68)
            .insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let radius = s * 0.14
        let outline = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
        outline.lineWidth = lineWidth
        outline.stroke()

        NSGraphicsContext.saveGraphicsState()
        outline.addClip()
        NSBezierPath(rect: NSRect(x: frame.minX, y: frame.minY, width: frame.width * 0.34, height: frame.height)).fill()
        NSGraphicsContext.restoreGraphicsState()

        // A short URL pill at the top of the page area.
        let pill = NSRect(x: frame.minX + frame.width * 0.44, y: frame.maxY - frame.height * 0.3,
                          width: frame.width * 0.44, height: max(1, frame.height * 0.1))
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
    }

    /// 18 pt template image for the menu bar.
    static func menuBarImage(_ badge: Badge) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.set()
            drawGlyph(in: rect.insetBy(dx: 0.5, dy: 1.5), lineWidth: 1.5)
            switch badge {
            case .none: break
            case .busy:
                for i in 0..<3 { NSBezierPath(ovalIn: NSRect(x: 5.5 + CGFloat(i) * 2.8, y: 0, width: 1.6, height: 1.6)).fill() }
            case .attention:
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: NSRect(x: 10, y: 0, width: 8.5, height: 8.5)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                NSBezierPath(ovalIn: NSRect(x: 11, y: 1, width: 6.5, height: 6.5)).fill()
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(rect: NSRect(x: 13.85, y: 3.6, width: 0.8, height: 2.6)).fill()
                NSBezierPath(rect: NSRect(x: 13.85, y: 2.3, width: 0.8, height: 0.8)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    /// Full-colour app icon at `size` px.
    static func appIcon(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { r in
            let box = r.insetBy(dx: size * 0.098, dy: size * 0.098)
            let tile = NSBezierPath(roundedRect: box, xRadius: box.width * 0.225, yRadius: box.width * 0.225)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.shadowBlurRadius = size * 0.02
            shadow.shadowOffset = NSSize(width: 0, height: -size * 0.008)
            shadow.set()
            NSColor.black.setFill(); tile.fill()
            NSGraphicsContext.restoreGraphicsState()

            NSGraphicsContext.saveGraphicsState()
            tile.addClip()
            NSGradient(colors: [NSColor(srgbRed: 0.25, green: 0.22, blue: 0.78, alpha: 1),
                                NSColor(srgbRed: 0.62, green: 0.30, blue: 0.86, alpha: 1),
                                NSColor(srgbRed: 1.00, green: 0.52, blue: 0.42, alpha: 1)],
                       atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: box, angle: 50)
            NSGradient(starting: NSColor.white.withAlphaComponent(0.18), ending: NSColor.white.withAlphaComponent(0))!
                .draw(in: NSRect(x: box.minX, y: box.midY, width: box.width, height: box.height / 2), angle: -90)
            NSColor.white.set()
            drawGlyph(in: box.insetBy(dx: box.width * 0.16, dy: box.width * 0.16), lineWidth: box.width * 0.06)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
    }

    /// Writes AppIcon.icns into `dir` (build step: `ArcPatches --make-icon <dir>`).
    static func writeICNS(to dir: URL) throws {
        let set = dir.appendingPathComponent("AppIcon.iconset")
        try? FileManager.default.removeItem(at: set)
        try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let px = CGFloat(base * scale)
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                appIcon(size: px).draw(in: NSRect(x: 0, y: 0, width: px, height: px))
                NSGraphicsContext.restoreGraphicsState()
                let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
                try rep.representation(using: .png, properties: [:])!.write(to: set.appendingPathComponent(name))
            }
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        p.arguments = ["-c", "icns", set.path, "-o", dir.appendingPathComponent("AppIcon.icns").path]
        try p.run(); p.waitUntilExit()
        try? FileManager.default.removeItem(at: set)
    }
}
