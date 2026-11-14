// The screenshot backdrop for frame.swift: an original flat screen print, computed per pixel
// from a seed. Paper, and a few hard-edged shapes in four pastel inks, each ink printed as
// its own slightly misregistered layer, knocked out of or overprinting (multiplying) the
// others, with fine print grain and one halftone. No gradients, no blur, no glow: flat
// inks and tiled grain also keep the PNGs small.
import CoreGraphics

typealias RGB = (r: Double, g: Double, b: Double)
private func hex(_ v: Int) -> RGB { (Double(v >> 16 & 255), Double(v >> 8 & 255), Double(v & 255)) }
let paper = hex(0xF3EDE2)
let printInk = hex(0x23211F)                        // frames and offset shadows
private let teal = hex(0x2F6B73), coral = hex(0xF28B74), amber = hex(0xE9A93B), pink = hex(0xF2B8B0)

private enum Cover { case none, solid, over }

struct Scene {
    var seed: UInt32
}

private func hash(_ x: Int, _ y: Int, _ s: UInt32) -> Double {
    var h = UInt32(truncatingIfNeeded: x &* 374761393) &+ UInt32(truncatingIfNeeded: y &* 668265263) &+ s &* 2246822519
    h = (h ^ (h >> 13)) &* 1274126177
    return Double(h ^ (h >> 16)) / Double(UInt32.max)
}

/// Smooth 1-D value noise in 0...1, summed over octaves.
private func fbm(_ x: Double, _ seed: UInt32, octaves: Int = 4) -> Double {
    var sum = 0.0, amp = 0.5, f = x, norm = 0.0
    for o in 0..<octaves {
        let i = Int(f.rounded(.down)), t = f - Double(i), s = t * t * (3 - 2 * t)
        let a = hash(i, o, seed), b = hash(i + 1, o, seed)
        sum += amp * (a + (b - a) * s); norm += amp
        amp *= 0.5; f *= 2.1
    }
    return sum / norm
}

/// Renders the scene at `w`×`h` pixels as an opaque RGB image.
func makeBackdrop(width w: Int, height h: Int, scene: Scene) -> CGImage {
    let bpr = w * 4, H = Double(h), W = Double(w), seed = scene.seed
    var px = [UInt8](repeating: 255, count: bpr * h)
    let r = { (k: Int) in hash(k, 7, seed) }                       // the scene's own dice
    let grain = (0..<(128 * 128)).map { hash($0 % 128, $0 / 128, seed &+ 5) }   // tiled, so it compresses
    // Each ink is a layer, off register by a few pixels.
    let off = (0..<4).map { (Int((r(10 + $0) - 0.5) * H / 80), Int((r(20 + $0) - 0.5) * H / 80)) }

    // Shapes, from the dice: a big pink disc, an amber half-disc rising from the bottom, a teal
    // range of hills with a coral stripe above it, a small coral disc, and teal halftone dots.
    let left = r(0) < 0.5
    let pinkC = ((left ? 0.22 : 0.78) * W + (r(1) - 0.5) * 0.1 * W, (0.3 + r(2) * 0.15) * H), pinkR = (0.36 + r(3) * 0.12) * H
    let amberC = ((left ? 0.8 : 0.2) * W, H * 1.02), amberR = (0.42 + r(4) * 0.1) * H
    let coralC = ((left ? 0.62 : 0.38) * W + (r(5) - 0.5) * 0.2 * W, (0.16 + r(6) * 0.1) * H), coralR = 0.07 * H
    let hills = (0..<w).map { x in (0.7 + 0.16 * (fbm(Double(x) / H * 1.6, seed &+ 9) - 0.5) * 2) * H }
    let stripe = (0..<w).map { x in (0.58 + 0.03 * sin(Double(x) / H * 7 + r(7) * 6)) * H }
    let dot = max(5.0, H / 70)

    func inDisc(_ x: Double, _ y: Double, _ c: (Double, Double), _ rad: Double) -> Bool {
        (x - c.0) * (x - c.0) + (y - c.1) * (y - c.1) < rad * rad
    }
    for y in 0..<h {
        for x in 0..<w {
            var c = paper
            // A shape is knocked out of the inks under it (`.solid`) or printed over them (`.over`).
            func ink(_ k: Int, _ col: RGB, _ covered: (Double, Double, Int) -> Cover) {
                let sx = x + off[k].0, sy = y + off[k].1
                let how = covered(Double(sx), Double(sy), min(w - 1, max(0, sx)))
                if how == .none || grain[((sy + 31 * k) & 127) * 128 + ((sx + 17 * k) & 127)] > 0.985 { return }   // ink skips: grain
                c = how == .solid ? col : (c.r * col.r / 255, c.g * col.g / 255, c.b * col.b / 255)
            }
            ink(0, pink) { x, y, _ in inDisc(x, y, pinkC, pinkR) ? .solid : .none }
            ink(1, amber) { x, y, _ in inDisc(x, y, amberC, amberR) ? .solid : .none }
            ink(2, coral) { x, y, i in inDisc(x, y, coralC, coralR) || abs(y - stripe[i]) < H * 0.012 ? .over : .none }
            ink(3, teal) { x, y, i in
                if y >= hills[i] { return .solid }
                // Halftone over the pink disc's lower half: dots that grow downward.
                guard inDisc(x, y, pinkC, pinkR), y > pinkC.1 else { return .none }
                let cx = (x / dot).rounded() * dot, cy = (y / dot).rounded() * dot
                let k = (y - pinkC.1) / pinkR
                return (x - cx) * (x - cx) + (y - cy) * (y - cy) < dot * dot * 0.2 * k * k ? .over : .none
            }
            if grain[(y & 127) * 128 + (x & 127)] < 0.006 { c = (c.r * 0.88, c.g * 0.88, c.b * 0.88) }   // paper fibre
            let p = y * bpr + x * 4
            px[p] = UInt8(c.r); px[p + 1] = UInt8(c.g); px[p + 2] = UInt8(c.b)
        }
    }
    let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bpr,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    return ctx.makeImage()!
}

/// Rounds every channel of an RGBX context to a multiple of `step`: invisible at 4 (text
/// edges move by at most 2/255), and it makes the finished PNGs about a third smaller.
func posterise(_ ctx: CGContext, step: Int = 4) {
    let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
    for i in 0..<(ctx.bytesPerRow * ctx.height) where i & 3 != 3 { p[i] = UInt8(min(256 - step, (Int(p[i]) + step / 2) / step * step)) }
}
