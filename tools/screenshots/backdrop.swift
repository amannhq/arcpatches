// The README backdrop for frame.swift: an original screen-print style landscape, computed
// per pixel from a seed. A banded teal night sky with stars, a big gold sun in a halftone
// glow, and ranges of hills from smooth noise, each flat-filled from one small palette and
// shaded only with ordered (Bayer) dither and a tiled grain. Flat inks and periodic
// patterns keep the PNGs small; per-pixel random noise would not compress.
import CoreGraphics
import CoreImage

typealias Ink = (r: UInt8, g: UInt8, b: UInt8)
let inks: [Ink] = [
    (0x0B, 0x0E, 0x12),   // 0 near-black
    (0x08, 0x26, 0x31),   // 1 night teal
    (0x0E, 0x3A, 0x48),   // 2 deep teal
    (0x1B, 0x54, 0x68),   // 3 teal
    (0xFF, 0x8A, 0x70),   // 4 coral
    (0xF2, 0xA9, 0x22),   // 5 gold
    (0xF3, 0xED, 0xE2),   // 6 bone
]

struct Scene {
    var seed: UInt32
    var sun: (x: Double, y: Double, r: Double)   // centre as fractions of width and height; radius of height
    var horizon = 0.52                            // where the far range sits, as a fraction of height
}

private func hash(_ x: Int, _ y: Int, _ s: UInt32) -> Double {
    var h = UInt32(truncatingIfNeeded: x &* 374761393) &+ UInt32(truncatingIfNeeded: y &* 668265263) &+ s &* 2246822519
    h = (h ^ (h >> 13)) &* 1274126177
    return Double(h ^ (h >> 16)) / Double(UInt32.max)
}

/// Smooth 1-D value noise in 0...1, summed over octaves.
private func fbm(_ x: Double, _ seed: UInt32, octaves: Int = 5) -> Double {
    var sum = 0.0, amp = 0.5, f = x, norm = 0.0
    for o in 0..<octaves {
        let i = Int(f.rounded(.down)), t = f - Double(i), s = t * t * (3 - 2 * t)
        let a = hash(i, o, seed), b = hash(i + 1, o, seed)
        sum += amp * (a + (b - a) * s); norm += amp
        amp *= 0.5; f *= 2.03
    }
    return sum / norm
}

private let bayer: [Double] = {
    let m: [Int] = [0, 32, 8, 40, 2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26, 12, 44, 4, 36, 14, 46, 6, 38,
                    60, 28, 52, 20, 62, 30, 54, 22, 3, 35, 11, 43, 1, 33, 9, 41, 51, 19, 59, 27, 49, 17, 57, 25,
                    15, 47, 7, 39, 13, 45, 5, 37, 63, 31, 55, 23, 61, 29, 53, 21]
    return m.map { (Double($0) + 0.5) / 64 }
}()

private func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(1, max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t)
}

/// Renders the scene at `w`×`h` pixels as an opaque RGB image.
func makeBackdrop(width w: Int, height h: Int, scene: Scene) -> CGImage {
    let bpr = w * 4
    var px = [UInt8](repeating: 255, count: bpr * h)
    let H = Double(h), dot = max(6.0, H / 90)              // halftone cell, in pixels
    let grain = (0..<(64 * 64)).map { hash($0 % 64, $0 / 64, scene.seed &+ 7) }   // tiled, so it compresses
    let sx = scene.sun.x * Double(w), sy = scene.sun.y * H, sr = scene.sun.r * H

    // Back to front: (ink, shade ink, base as a fraction of height, amplitude, frequency per height).
    let ranges: [(Int, Int, Double, Double, Double)] = [
        (4, 3, scene.horizon + 0.02, 0.20, 2.4),
        (2, 1, scene.horizon + 0.16, 0.16, 1.7),
        (1, 0, scene.horizon + 0.29, 0.13, 1.3),
        (0, 0, scene.horizon + 0.41, 0.10, 1.0),
    ]
    var ridges = [[Double]](repeating: [Double](repeating: 0, count: w), count: ranges.count)
    for (k, r) in ranges.enumerated() {
        for x in 0..<w {
            let n = fbm(Double(x) / H * r.4 + Double(k) * 17.3, scene.seed &+ UInt32(k * 31))
            ridges[k][x] = (r.2 - r.3 * (n - 0.5) * 3.2) * H
        }
    }
    let sky: [(Double, Int)] = [(0.0, 1), (0.24, 2), (0.42, 3)]

    for y in 0..<h {
        let fy = Double(y)
        for x in 0..<w {
            let b = bayer[(y & 7) * 8 + (x & 7)], g = grain[(y & 63) * 64 + (x & 63)]
            let t = b * 0.75 + g * 0.25                          // dither threshold, roughened by grain
            var ink = 1

            // Sky: posterised bands with a dithered seam between each pair.
            let v = fy / H
            for i in 0..<(sky.count - 1) where v >= sky[i].0 {
                let span = sky[i + 1].0 - sky[i].0
                ink = smooth(0.55, 1.0, (v - sky[i].0) / span) > t ? sky[i + 1].1 : sky[i].1
            }
            if v >= sky.last!.0 { ink = 3 }
            // Stars in the upper sky: sparse 2×2 bone specks.
            if v < 0.4, hash(x / 3, y / 3, scene.seed &+ 3) > 0.9985 - (0.4 - v) * 0.002 { ink = 6 }

            // Sun: a gold disc with a bone halftone core, in a halftone glow of gold.
            let dx = Double(x) - sx, dy = fy - sy, d = (dx * dx + dy * dy).squareRoot()
            let cx = (Double(x) / dot).rounded() * dot, cy = (fy / dot).rounded() * dot   // halftone cell centre
            if d < sr {
                ink = 5
                let core = 1 - smooth(0.0, 0.85, ((Double(x) - sx + sr * 0.3) * (Double(x) - sx + sr * 0.3) + (fy - sy + sr * 0.3) * (fy - sy + sr * 0.3)).squareRoot() / sr)
                let dd = ((Double(x) - cx) * (Double(x) - cx) + (fy - cy) * (fy - cy)).squareRoot()
                if dd < dot * 0.62 * core { ink = 6 }
            } else if d < sr * 1.9 {
                let k = 1 - (d - sr) / (sr * 0.9)
                let dd = ((Double(x) - cx) * (Double(x) - cx) + (fy - cy) * (fy - cy)).squareRoot()
                if dd < dot * 0.55 * k * k { ink = d < sr * 1.25 ? 5 : 4 }
            }

            // Hills: flat ink, darkening downward through dither; sunward ridges catch light.
            for (k, r) in ranges.enumerated() where fy >= ridges[k][x] {
                let depth = (fy - ridges[k][x]) / H
                ink = smooth(0.02, 0.22, depth) > t ? r.1 : r.0
                let slope = x + 1 < w ? ridges[k][x + 1] - ridges[k][x] : 0
                let sunward = (Double(x) < sx) == (slope > 0)
                if sunward, depth < 0.02, smooth(0.02, 0.004, depth) * min(1, abs(slope) * 1.5) > t {
                    ink = k == 0 ? 6 : (k == 1 ? 4 : 3)
                }
                if g > 0.994, ink < 4 { ink += 1 }            // riso speckle
            }

            let c = inks[ink], p = y * bpr + x * 4
            px[p] = c.r; px[p + 1] = c.g; px[p + 2] = c.b
        }
    }
    let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bpr,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    return ctx.makeImage()!
}

/// What a glass panel sees: `img` blurred by `sigma` pixels, richer and a little darker.
/// Blurred at 1/8 scale and scaled back smoothly: a full-size blur's ±1 noise doesn't compress.
func frost(_ img: CGImage, sigma: CGFloat) -> CGImage {
    let w = img.width, h = img.height, k: CGFloat = 8
    let small = CIImage(cgImage: img).applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 1 / k])
    let e = small.extent.integral
    let blurred = small.clampedToExtent().applyingGaussianBlur(sigma: sigma / k)
        .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.35, kCIInputBrightnessKey: -0.06])
        .cropped(to: e)
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .medium
    ctx.draw(CIContext().createCGImage(blurred, from: e)!, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()!
}

/// Rounds every channel of an RGBX context to a multiple of 4: invisible (blur, shadows and
/// text edges move by at most 2/255), and it makes the finished PNGs about a third smaller.
func posterise(_ ctx: CGContext) {
    let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
    for i in 0..<(ctx.bytesPerRow * ctx.height) where i & 3 != 3 { p[i] = UInt8(min(252, (Int(p[i]) + 2) & ~3)) }
}
