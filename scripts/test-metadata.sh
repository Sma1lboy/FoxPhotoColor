#!/bin/bash
# Self-check for PhotoMetadataParser: builds it against a tiny driver on macOS
# (the file only needs Foundation/ImageIO/CoreLocation), writes a JPEG with
# known EXIF+GPS, parses it back, asserts. Fails loudly if parsing breaks.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/main.swift" <<'EOF'
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Build a 4x4 JPEG carrying EXIF DateTimeOriginal + GPS via ImageIO.
let ctx = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(red: 1, green: 0.5, blue: 0, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
let img = ctx.makeImage()!

let url = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
let props: [CFString: Any] = [
    kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2024:11:03 19:05:00"],
    kCGImagePropertyGPSDictionary: [
        kCGImagePropertyGPSLatitude: 34.4347, kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 135.2440, kCGImagePropertyGPSLongitudeRef: "E",
    ],
]
CGImageDestinationAddImage(dest, img, props as CFDictionary)
CGImageDestinationFinalize(dest)

let data = try! Data(contentsOf: url)
let meta = PhotoMetadataParser.parse(from: data)

assert(meta.coordinate != nil, "GPS should parse")
assert(abs(meta.coordinate!.latitude - 34.4347) < 0.001, "latitude wrong: \(meta.coordinate!.latitude)")
assert(abs(meta.coordinate!.longitude - 135.2440) < 0.001, "longitude wrong")
assert(meta.creationDate != nil, "EXIF date should parse")
let cal = Calendar.current
let c = cal.dateComponents([.year, .hour, .minute], from: meta.creationDate!)
assert(c.year == 2024 && c.hour == 19 && c.minute == 5, "date components wrong: \(c)")

// Southern/western hemisphere signs
let dest2 = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
let props2: [CFString: Any] = [
    kCGImagePropertyGPSDictionary: [
        kCGImagePropertyGPSLatitude: 36.8485, kCGImagePropertyGPSLatitudeRef: "S",
        kCGImagePropertyGPSLongitude: 174.7633, kCGImagePropertyGPSLongitudeRef: "W",
    ],
]
CGImageDestinationAddImage(dest2, img, props2 as CFDictionary)
CGImageDestinationFinalize(dest2)
let meta2 = PhotoMetadataParser.parse(from: try! Data(contentsOf: url))
assert(meta2.coordinate!.latitude < 0 && meta2.coordinate!.longitude < 0, "hemisphere refs should negate")
assert(meta2.creationDate == nil, "no EXIF date -> nil")

print("PhotoMetadataParser self-check: OK")
EOF

swiftc -o "$TMP/check" FoxPhotoColor/Support/PhotoMetadata.swift "$TMP/main.swift"
"$TMP/check" "$TMP/probe.jpg"
