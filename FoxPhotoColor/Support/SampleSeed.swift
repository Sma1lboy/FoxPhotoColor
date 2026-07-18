import SwiftUI
import UIKit

/// Debug/QA harness: when launched with FPC_SEED=1 and the store is empty,
/// generates three synthetic "photos" and cards so the full card UI can be
/// screenshotted without touching the photo picker.
enum SampleSeed {

    @MainActor
    static func seedIfNeeded(into store: CardStore) {
        guard ProcessInfo.processInfo.environment["FPC_SEED"] == "1",
              store.cards.isEmpty else { return }
        for spec in specs.reversed() {
            let image = render(spec)
            let palette = PaletteExtractor.extract(from: image)
            store.add(image: image, title: spec.title, timeText: spec.time, palette: palette)
        }
    }

    private struct Spec {
        let title: String
        let time: String
        let stops: [(UIColor, CGFloat)]
        let sun: (center: CGPoint, radius: CGFloat, color: UIColor)?
        let ground: UIColor?
    }

    private static let specs: [Spec] = [
        Spec(title: "KANSAI INTERNATIONAL AIRPORT",
             time: "7:05 PM",
             stops: [(UIColor(red: 0.55, green: 0.62, blue: 0.75, alpha: 1), 0.0),
                     (UIColor(red: 0.95, green: 0.68, blue: 0.35, alpha: 1), 0.45),
                     (UIColor(red: 0.98, green: 0.45, blue: 0.20, alpha: 1), 0.62),
                     (UIColor(red: 0.35, green: 0.25, blue: 0.22, alpha: 1), 0.75)],
             sun: (CGPoint(x: 0.5, y: 0.60), 60, UIColor(red: 1.0, green: 0.85, blue: 0.55, alpha: 1)),
             ground: UIColor(red: 0.22, green: 0.18, blue: 0.16, alpha: 1)),
        Spec(title: "OSAKA",
             time: "12:51 PM",
             stops: [(UIColor(red: 0.45, green: 0.62, blue: 0.85, alpha: 1), 0.0),
                     (UIColor(red: 0.62, green: 0.76, blue: 0.92, alpha: 1), 0.6),
                     (UIColor(red: 0.80, green: 0.87, blue: 0.95, alpha: 1), 1.0)],
             sun: (CGPoint(x: 0.68, y: 0.45), 46, UIColor(red: 0.75, green: 0.15, blue: 0.12, alpha: 1)),
             ground: nil),
        Spec(title: "MAUNGAWHAU / MOUNT EDEN",
             time: "7:11 PM",
             stops: [(UIColor(red: 0.28, green: 0.38, blue: 0.28, alpha: 1), 0.0),
                     (UIColor(red: 0.42, green: 0.55, blue: 0.32, alpha: 1), 0.5),
                     (UIColor(red: 0.60, green: 0.68, blue: 0.42, alpha: 1), 1.0)],
             sun: (CGPoint(x: 0.3, y: 0.3), 40, UIColor(red: 0.92, green: 0.93, blue: 0.88, alpha: 1)),
             ground: UIColor(red: 0.20, green: 0.28, blue: 0.18, alpha: 1)),
    ]

    private static func render(_ spec: Spec) -> UIImage {
        let size = CGSize(width: 900, height: 1100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = spec.stops.map { $0.0.cgColor } as CFArray
            let locations = spec.stops.map { $0.1 }
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: locations) {
                cg.drawLinearGradient(gradient,
                                      start: .zero,
                                      end: CGPoint(x: 0, y: size.height),
                                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            if let sun = spec.sun {
                cg.setFillColor(sun.color.cgColor)
                let c = CGPoint(x: sun.center.x * size.width, y: sun.center.y * size.height)
                cg.fillEllipse(in: CGRect(x: c.x - sun.radius, y: c.y - sun.radius,
                                          width: sun.radius * 2, height: sun.radius * 2))
            }
            if let ground = spec.ground {
                cg.setFillColor(ground.cgColor)
                cg.fill(CGRect(x: 0, y: size.height * 0.78,
                               width: size.width, height: size.height * 0.22))
            }
        }
    }
}
