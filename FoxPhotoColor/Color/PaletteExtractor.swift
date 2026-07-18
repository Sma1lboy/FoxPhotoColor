import UIKit
import simd

struct ExtractedPalette {
    var background: RGBAColor
    var accent: RGBAColor
    var swatches: [RGBAColor]
}

/// Dominant-color extraction: downsample → deterministic k-means → derive a muted
/// poster background and a legible contrasting accent, in the spirit of the
/// reference "adaptive minimalist" aesthetic.
enum PaletteExtractor {

    static func extract(from image: UIImage) -> ExtractedPalette {
        let pixels = samplePixels(image, side: 64)
        guard pixels.count > 16 else {
            return ExtractedPalette(background: RGBAColor(r: 0.45, g: 0.52, b: 0.38),
                                    accent: RGBAColor(r: 0.95, g: 0.93, b: 0.85),
                                    swatches: [])
        }
        let clusters = kMeans(pixels: pixels, k: 6, iterations: 14)
        let swatches = clusters.map { RGBAColor(r: $0.center.x, g: $0.center.y, b: $0.center.z) }

        let background = deriveBackground(from: swatches[0])
        let accent = deriveAccent(candidates: swatches, background: background)
        return ExtractedPalette(background: background, accent: accent, swatches: swatches)
    }

    /// Re-derive background + accent when the user picks a different palette
    /// swatch as the card's base color.
    static func rederive(from swatch: RGBAColor, palette: [RGBAColor]) -> (background: RGBAColor, accent: RGBAColor) {
        let background = deriveBackground(from: swatch)
        let accent = deriveAccent(candidates: palette.isEmpty ? [swatch] : palette, background: background)
        return (background, accent)
    }

    // MARK: - Derivation

    /// Mute the dominant color into a poster background: cap saturation, keep the
    /// photo's light/dark mood but stay inside a comfortable band.
    private static func deriveBackground(from dominant: RGBAColor) -> RGBAColor {
        var (h, s, b) = dominant.hsb
        s = min(s * 0.85, 0.48)
        if s < 0.05 { s = 0.07 } // keep a faint tint instead of pure gray
        b = min(max(b, 0.30), 0.78)
        return .fromHSB(h: h, s: s, b: b)
    }

    /// Pick the cluster that reads best against the background, then push its
    /// brightness away from the background for legibility.
    private static func deriveAccent(candidates: [RGBAColor], background: RGBAColor) -> RGBAColor {
        let bgHSB = background.hsb
        var best: (color: RGBAColor, score: Double)? = nil
        for c in candidates {
            let (h, s, b) = c.hsb
            let hueDist = min(abs(h - bgHSB.h), 1 - abs(h - bgHSB.h)) // circular
            let brightDist = abs(b - bgHSB.b)
            let score = (0.35 + s) * (hueDist * 1.4 + brightDist)
            if best == nil || score > best!.score {
                best = (c, score)
            }
        }
        var (h, s, b) = (best?.color ?? background).hsb
        s = max(s, 0.30)
        if background.isLight {
            b = min(b, 0.42)
            s = min(max(s, 0.45), 0.85)
        } else {
            b = max(b, 0.78)
        }
        var accent = RGBAColor.fromHSB(h: h, s: s, b: b)

        // HSB brightness is not perceived luminance (saturated blue at b=0.9 is
        // still dark) — enforce a real luminance gap, falling back to warm
        // near-white / near-black when hue alone can't get there.
        let bgLum = background.luminance
        if abs(accent.luminance - bgLum) < 0.28 {
            if bgLum > 0.5 {
                b = max(0.18, b - 0.30)
                s = min(s + 0.15, 0.90)
            } else {
                s = min(s, 0.45)
                b = min(1.0, b + 0.25)
            }
            accent = .fromHSB(h: h, s: s, b: b)
            if abs(accent.luminance - bgLum) < 0.28 {
                accent = bgLum > 0.5
                    ? RGBAColor(r: 0.16, g: 0.15, b: 0.13)
                    : RGBAColor(r: 0.96, g: 0.94, b: 0.89)
            }
        }
        return accent
    }

    // MARK: - Sampling

    private static func samplePixels(_ image: UIImage, side: Int) -> [simd_double3] {
        guard let cgImage = image.cgImage else { return [] }
        let width = side, height = side
        var raw = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &raw,
                                  width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.interpolationQuality = .medium
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [simd_double3] = []
        pixels.reserveCapacity(width * height)
        for i in stride(from: 0, to: raw.count, by: 4) {
            let a = raw[i + 3]
            guard a > 128 else { continue }
            pixels.append(simd_double3(Double(raw[i]) / 255.0,
                                       Double(raw[i + 1]) / 255.0,
                                       Double(raw[i + 2]) / 255.0))
        }
        return pixels
    }

    // MARK: - Clustering

    struct Cluster {
        var center: simd_double3
        var count: Int
    }

    /// Deterministic k-means: initial centers are luminance quantiles, so the same
    /// photo always yields the same palette.
    private static func kMeans(pixels: [simd_double3], k: Int, iterations: Int) -> [Cluster] {
        let sorted = pixels.sorted {
            luminance($0) < luminance($1)
        }
        var centers: [simd_double3] = (0..<k).map { i in
            sorted[(sorted.count - 1) * (2 * i + 1) / (2 * k)]
        }
        var counts = [Int](repeating: 0, count: k)

        for _ in 0..<iterations {
            var sums = [simd_double3](repeating: .zero, count: k)
            counts = [Int](repeating: 0, count: k)
            for p in pixels {
                var bestIdx = 0
                var bestDist = Double.greatestFiniteMagnitude
                for (idx, c) in centers.enumerated() {
                    let d = simd_distance_squared(p, c)
                    if d < bestDist { bestDist = d; bestIdx = idx }
                }
                sums[bestIdx] += p
                counts[bestIdx] += 1
            }
            for i in 0..<k where counts[i] > 0 {
                centers[i] = sums[i] / Double(counts[i])
            }
        }

        return zip(centers, counts)
            .map { Cluster(center: $0, count: $1) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    private static func luminance(_ p: simd_double3) -> Double {
        0.299 * p.x + 0.587 * p.y + 0.114 * p.z
    }
}
