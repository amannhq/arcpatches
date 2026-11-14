// frame.swift's second job: the website's per-setting stills and animated demos, from the
// raw renders in <raw-dir>/settings and <raw-dir>/anim (shots-settings.m, shots-anim.m).
// Stills are tighter crops of the README framing. Each animation becomes one APNG that
// loops: frames that repeat are merged into one longer frame, and each later frame stores
// only the rectangle that changed, so a few seconds at 30 fps stay small.
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// A scene per file name, so each image gets its own hills but the same look.
private func scene(for name: String, sunRadius: Double) -> Scene {
    let seed = name.unicodeScalars.reduce(UInt32(7)) { $0 &* 31 &+ $1.value }
    let left = seed % 2 == 0
    return Scene(seed: seed, sun: (left ? 0.14 : 0.86, 0.22, sunRadius))
}

private func radius(for name: String) -> CGFloat {
    name.hasPrefix("commandBarStyle") ? 14 : 12
}

func frameSettings() {
    let fm = FileManager.default
    try? fm.createDirectory(at: out.appendingPathComponent("settings"), withIntermediateDirectories: true)
    let stills = (try? fm.contentsOfDirectory(atPath: raw.appendingPathComponent("settings").path)) ?? []
    for file in stills.sorted() where file.hasSuffix(".png") {
        let name = "settings/" + file, img = load(name), pad: CGFloat = 36
        let size = NSSize(width: img.size.width + pad * 2, height: img.size.height + pad * 2)
        render(size: size, to: name, scene: scene(for: file, sunRadius: size.height > 300 ? 0.2 : 0.34)) { _ in
            panel(img, at: NSPoint(x: pad, y: pad + 4), radius: radius(for: file))
        }
    }
    let anims = (try? fm.contentsOfDirectory(atPath: raw.appendingPathComponent("anim").path)) ?? []
    for dir in anims.sorted() { animation(dir) }
    writeManifest()
}

/// settings/manifest.json: what each image shows, for the website. Titles are the Settings
/// pane's; `on`/`off` are stills, `demo` an APNG that loops (play it as a plain <img>).
private func writeManifest() {
    func s(_ key: String, _ title: String, on: String?, off: String?, demo: String? = nil, note: String? = nil) -> [String: String] {
        var d = ["key": "arcpatches." + key, "title": title]
        d["on"] = on; d["off"] = off; d["demo"] = demo; d["note"] = note
        return d
    }
    let png = { (k: String, v: String) in "\(k)-\(v).png" }
    let items: [[String: String]] = [
        s("urlBarMode", "URL bar position", on: png("urlBarMode", "on"), off: png("urlBarMode", "off"),
          note: "on: In sidebar. off: Top (Dia default), Dia's own bar drawn as a generic stand-in."),
        s("sidebarPillButtons", "Copy link and site controls", on: png("sidebarPillButtons", "on"), off: png("sidebarPillButtons", "off"),
          demo: "demo-pill-hover.png"),
        s("sidebarShowsFullURL", "Show full URL", on: png("sidebarShowsFullURL", "on"), off: png("sidebarShowsFullURL", "off")),
        s("sidebarShowsNavButtons", "Back, forward and reload buttons", on: png("sidebarShowsNavButtons", "on"),
          off: png("sidebarShowsNavButtons", "off"), demo: "demo-reload-spin.png"),
        s("sidebarToggleButton", "Sidebar toggle button", on: png("sidebarToggleButton", "on"), off: png("sidebarToggleButton", "off")),
        s("topRowProfileName", "Profile name in top row", on: png("topRowProfileName", "on"), off: png("topRowProfileName", "off"),
          note: "on: Dia's profile name (stand-in label) can sit under the back and forward buttons."),
        s("hideWindowButtonsInFullScreen", "Hide window buttons in full screen", on: png("hideWindowButtonsInFullScreen", "on"),
          off: png("hideWindowButtonsInFullScreen", "off"), demo: "demo-fullscreen-strip.png",
          note: "hideWindowButtonsInFullScreen-on-strip.png: the title strip shown at the top edge."),
        s("commandBarStyle", "Command bar", on: png("commandBarStyle", "on"), off: nil, demo: "demo-palette.png",
          note: "on: ArcPatches (Arc-style). Dia's editor and Off show Dia's own UI, not rendered."),
        s("cmdLFocusesSidebar", "⌘L opens the sidebar URL bar", on: png("cmdLFocusesSidebar", "on"), off: nil,
          note: "off: Dia's editor at the top, not rendered."),
        s("emptyState", "No page open", on: "empty-state.png", off: nil, note: "Not a setting: the pill with no page."),
        s("copyLink", "Copy link feedback", on: nil, off: nil, demo: "demo-copy-link.png", note: "Not a setting: clicking copy link."),
    ]
    let json = try! JSONSerialization.data(withJSONObject: ["fps": 30, "loop": true, "items": items] as [String: Any],
                                           options: [.prettyPrinted, .sortedKeys])
    try! json.write(to: out.appendingPathComponent("settings/manifest.json"))
}

/// One animation: every frame on the same glass and backdrop, then an APNG.
private func animation(_ name: String) {
    let dir = raw.appendingPathComponent("anim/" + name)
    let files = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".png") }.sorted()
    guard let first = files.first else { return }
    var timeline: [String: [Double]] = [:]
    if let data = try? Data(contentsOf: dir.appendingPathComponent("panel.json")),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: [Double]] { timeline = json }
    let big = load("anim/\(name)/\(first)").size.width > 400
    let saved = (scale, posterStep)
    // A whole wide panel changes in every frame of its fade: at 1x and in coarser steps it stays small.
    if big { scale = 1; posterStep = 8 }
    defer { (scale, posterStep) = saved }
    let pad: CGFloat = big ? 40 : 36, size0 = load("anim/\(name)/\(first)").size
    let size = NSSize(width: size0.width + pad * 2, height: size0.height + pad * 2)
    canvas = Canvas(pixels: Int(size.width * scale), Int(size.height * scale), scene: scene(for: name, sunRadius: big ? 0.22 : 0.34))
    var frames: [CGImage] = []
    for (i, f) in files.enumerated() {
        let img = load("anim/\(name)/\(f)")
        let a = timeline["alpha"].map { CGFloat($0[i]) } ?? 1, z = timeline["scale"].map { CGFloat($0[i]) } ?? 1
        frames.append(compose(size: size) { _ in panel(img, at: NSPoint(x: pad, y: pad + 4), radius: big ? 14 : 12, alpha: a, zoom: z) })
    }
    let url = out.appendingPathComponent("settings/demo-\(name).png")
    try! writeAPNG(frames, fps: 30, to: url)
    print("wrote", url.path, "(\(frames.count) frames)")
}

// MARK: - APNG

private let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
    var c = UInt32(n)
    for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
    return c
}

private func chunk(_ type: String, _ body: Data) -> Data {
    var d = Data(), t = Data(type.utf8)
    d.append(be32(UInt32(body.count))); d.append(t); d.append(body)
    var c: UInt32 = 0xFFFFFFFF
    for b in t + body { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
    d.append(be32(c ^ 0xFFFFFFFF))
    return d
}
private func be32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.bigEndian) { Data($0) } }
private func be16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.bigEndian) { Data($0) } }

/// ImageIO's PNG of `img`, split into (IHDR body, concatenated IDAT bodies).
private func encode(_ img: CGImage) -> (Data, Data) {
    let d = NSMutableData()
    let dest = CGImageDestinationCreateWithData(d, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    let bytes = d as Data
    var i = 8, ihdr = Data(), idat = Data()
    while i + 8 <= bytes.count {
        let len = Int(bytes[i..<i + 4].reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        let type = String(decoding: bytes[i + 4..<i + 8], as: UTF8.self), body = bytes[i + 8..<i + 8 + len]
        if type == "IHDR" { ihdr = Data(body) } else if type == "IDAT" { idat.append(body) }
        i += 12 + len
    }
    return (ihdr, idat)
}

private func pixels(_ img: CGImage) -> [UInt32] {
    var buf = [UInt32](repeating: 0, count: img.width * img.height)
    let ctx = CGContext(data: &buf, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: img.width * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
    return buf
}

/// Writes `frames` (all the same size) as a looping APNG at `fps`.
func writeAPNG(_ frames: [CGImage], fps: Int, to url: URL) throws {
    let w = frames[0].width, h = frames[0].height
    // Runs of identical frames become one frame with a longer delay; each keeps its changed rectangle.
    var parts: [(img: CGImage, rect: CGRect, ticks: Int)] = []
    var prev: [UInt32] = []
    for f in frames {
        let px = pixels(f)
        if prev.isEmpty { parts.append((f, CGRect(x: 0, y: 0, width: w, height: h), 1)); prev = px; continue }
        var x0 = w, y0 = h, x1 = -1, y1 = -1
        for y in 0..<h { for x in 0..<w where px[y * w + x] != prev[y * w + x] {
            x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
        } }
        if x1 < 0 { parts[parts.count - 1].ticks += 1; continue }
        parts.append((f, CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1), 1))
        prev = px
    }
    var png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), seq: UInt32 = 0
    for (n, p) in parts.enumerated() {
        let (ihdr, idat) = encode(n == 0 ? p.img : p.img.cropping(to: p.rect)!)
        if n == 0 {
            png.append(chunk("IHDR", ihdr))
            png.append(chunk("acTL", be32(UInt32(parts.count)) + be32(0)))   // 0: loop forever
        }
        var fc = be32(seq) + be32(UInt32(p.rect.width)) + be32(UInt32(p.rect.height))
        fc += be32(UInt32(p.rect.minX)) + be32(UInt32(p.rect.minY))
        fc += be16(UInt16(p.ticks)) + be16(UInt16(fps)) + Data([0, 0])   // dispose none, blend source
        png.append(chunk("fcTL", fc)); seq += 1
        if n == 0 { png.append(chunk("IDAT", idat)) } else { png.append(chunk("fdAT", be32(seq) + idat)); seq += 1 }
    }
    png.append(chunk("IEND", Data()))
    try png.write(to: url)
}
