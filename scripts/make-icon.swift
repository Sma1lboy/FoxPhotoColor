// Generates the app icon (1024x1024 PNG): green gradient field with the
// three-ellipse logo mark. Run: swift scripts/make-icon.swift
import AppKit
import CoreGraphics

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: size, height: size,
                    bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Background: soft vertical green gradient (matches empty state)
let bgColors = [
    CGColor(red: 0.58, green: 0.67, blue: 0.45, alpha: 1),
    CGColor(red: 0.42, green: 0.53, blue: 0.33, alpha: 1),
] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: CGFloat(size)),
                       end: CGPoint(x: 0, y: 0), options: [])

func ellipse(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, color: CGColor, alpha: CGFloat = 1) {
    ctx.setAlpha(alpha)
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
    ctx.setAlpha(1)
}

// Logo mark, centered; CG y-axis is bottom-up so "top" = larger y
let cx: CGFloat = 512
let w: CGFloat = 340, h: CGFloat = 400
ellipse(cx: cx, cy: 512 - 76, w: w, h: h, color: CGColor(red: 0.16, green: 0.22, blue: 0.11, alpha: 1))
ellipse(cx: cx, cy: 512, w: w, h: h, color: CGColor(red: 0.45, green: 0.56, blue: 0.30, alpha: 1))
ellipse(cx: cx, cy: 512 + 76, w: w, h: h, color: CGColor(red: 0.85, green: 0.90, blue: 0.68, alpha: 1), alpha: 0.94)

let cgImage = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: cgImage)
let png = rep.representation(using: .png, properties: [:])!
let out = URL(fileURLWithPath: "FoxPhotoColor/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
try! png.write(to: out)
print("wrote \(out.path)")
