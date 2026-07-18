#!/bin/bash
# Unit tests for the color pipeline (PaletteExtractor + RGBAColor), executed
# INSIDE the iOS simulator: compile a CLI against the iphonesimulator SDK and
# run it with `simctl spawn`. No test target / pbxproj surgery needed.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app}"
SIM_NAME="${SIM_NAME:-iPhone 16 Pro}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

UDID=$(xcrun simctl list devices available | grep -F "$SIM_NAME (" | head -1 | grep -oE '[0-9A-F-]{36}')
xcrun simctl bootstatus "$UDID" -b >/dev/null

cat > "$TMP/main.swift" <<'EOF'
import UIKit
import simd

func gradientImage(_ stops: [(UIColor, CGFloat)], size: Int = 200, dot: (UIColor, CGFloat)? = nil) -> UIImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let colors = stops.map { $0.0.cgColor } as CFArray
    let locs = stops.map { $0.1 }
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs)!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size), options: [])
    if let (color, radius) = dot {
        ctx.setFillColor(color.cgColor)
        let c = CGFloat(size) / 2
        ctx.fillEllipse(in: CGRect(x: c - radius, y: c - radius, width: radius * 2, height: radius * 2))
    }
    return UIImage(cgImage: ctx.makeImage()!)
}

var failures = 0
func check(_ cond: Bool, _ name: String) {
    if cond { print("PASS \(name)") } else { failures += 1; print("FAIL \(name)") }
}

// 1. Determinism: identical input -> identical palette
let sunset = gradientImage([(UIColor(red: 0.95, green: 0.6, blue: 0.3, alpha: 1), 0),
                            (UIColor(red: 0.3, green: 0.2, blue: 0.25, alpha: 1), 1)])
let a = PaletteExtractor.extract(from: sunset)
let b = PaletteExtractor.extract(from: sunset)
check(a.background == b.background && a.accent == b.accent && a.swatches == b.swatches,
      "extraction is deterministic")

// 2. Perceived-luminance gap on hostile inputs (saturated blue, near-black, near-white, gray)
let cases: [(String, UIImage)] = [
    ("saturated blue", gradientImage([(UIColor(red: 0.05, green: 0.1, blue: 0.9, alpha: 1), 0),
                                      (UIColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 1), 1)])),
    ("dark forest", gradientImage([(UIColor(red: 0.05, green: 0.12, blue: 0.04, alpha: 1), 0),
                                   (UIColor(red: 0.12, green: 0.22, blue: 0.10, alpha: 1), 1)])),
    ("bright sky", gradientImage([(UIColor(red: 0.85, green: 0.92, blue: 0.98, alpha: 1), 0),
                                  (UIColor(red: 0.65, green: 0.8, blue: 0.95, alpha: 1), 1)],
                                 dot: (UIColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1), 20))),
    ("flat gray", gradientImage([(UIColor(white: 0.5, alpha: 1), 0), (UIColor(white: 0.55, alpha: 1), 1)])),
]
for (name, img) in cases {
    let p = PaletteExtractor.extract(from: img)
    let gap = abs(p.background.luminance - p.accent.luminance)
    check(gap >= 0.27, "luminance gap \(String(format: "%.2f", gap)) on \(name)")
    check(p.background.r >= 0 && p.background.r <= 1, "background sane on \(name)")
}

// 3. Degenerate input: tiny image must not crash and still yields usable colors
let tiny = gradientImage([(UIColor.red, 0), (UIColor.blue, 1)], size: 2)
let tp = PaletteExtractor.extract(from: tiny)
check(tp.background.luminance >= 0 && tp.background.luminance <= 1, "2x2 image survives")

// 4. RGBAColor JSON round-trip is exact (ring state must survive relaunch)
let p = PaletteExtractor.extract(from: sunset)
let data = try! JSONEncoder().encode(p.swatches)
let decoded = try! JSONDecoder().decode([RGBAColor].self, from: data)
check(decoded == p.swatches, "RGBAColor JSON round-trip exact")

// 5. rederive: every swatch keeps the legibility guarantee
for (i, s) in p.swatches.enumerated() {
    let d = PaletteExtractor.rederive(from: s, palette: p.swatches)
    let gap = abs(d.background.luminance - d.accent.luminance)
    check(gap >= 0.27, "rederive luminance gap on swatch \(i)")
}

// 6. Performance floor: 12MP-class input must stay interactive.
let big = gradientImage([(UIColor(red: 0.9, green: 0.55, blue: 0.3, alpha: 1), 0),
                         (UIColor(red: 0.2, green: 0.25, blue: 0.4, alpha: 1), 1)],
                        size: 3500,
                        dot: (UIColor(red: 0.95, green: 0.9, blue: 0.6, alpha: 1), 300))
let t0 = CFAbsoluteTimeGetCurrent()
_ = PaletteExtractor.extract(from: big)
let dt = CFAbsoluteTimeGetCurrent() - t0
check(dt < 2.0, "12MP extraction in \(String(format: "%.3f", dt))s (< 2s)")

if failures > 0 { print("\(failures) FAILURES"); exit(1) }
print("palette tests: ALL PASS")
EOF

SDK=$(xcrun -sdk iphonesimulator --show-sdk-path)
xcrun -sdk iphonesimulator swiftc \
  -target arm64-apple-ios17.0-simulator -sdk "$SDK" \
  -o "$TMP/palette-tests" \
  FoxPhotoColor/Models/ColorCard.swift \
  FoxPhotoColor/Models/CameraInfo.swift \
  FoxPhotoColor/Color/PaletteExtractor.swift \
  "$TMP/main.swift"

xcrun simctl spawn "$UDID" "$TMP/palette-tests"
