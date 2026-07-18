import SwiftUI
import UIKit

/// A serializable RGB color. Stored 0...1 per channel.
struct RGBAColor: Codable, Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(uiColor: UIColor) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(r: Double(red), g: Double(green), b: Double(blue))
    }

    var color: Color { Color(red: r, green: g, blue: b) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }

    /// Perceived luminance (sRGB approximation).
    var luminance: Double { 0.299 * r + 0.587 * g + 0.114 * b }
    var isLight: Bool { luminance > 0.6 }

    var hexString: String {
        String(format: "#%02X%02X%02X",
               Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    /// Hue/saturation/brightness — for palette derivation.
    var hsb: (h: Double, s: Double, b: Double) {
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        return (Double(h), Double(s), Double(br))
    }

    static func fromHSB(h: Double, s: Double, b: Double) -> RGBAColor {
        RGBAColor(uiColor: UIColor(hue: h, saturation: s, brightness: b, alpha: 1))
    }

    /// Canvas endpoints behind the poster card. The reference renders a radial
    /// wash from the top-leading corner: card lightened 24% toward white there,
    /// darkened 14% toward black past the card — the card color sits mid-ramp.
    var canvasLight: RGBAColor { mixed(toward: 1, fraction: 0.24) }
    var canvasDark: RGBAColor { mixed(toward: 0, fraction: 0.14) }

    private func mixed(toward target: Double, fraction: Double) -> RGBAColor {
        RGBAColor(r: r + (target - r) * fraction,
                  g: g + (target - g) * fraction,
                  b: b + (target - b) * fraction)
    }
}

/// A point in unit space (0...1 of the screen) — device-size independent.
struct NormalizedPoint: Codable, Equatable {
    var x: Double
    var y: Double
}

/// Poster style for the main card browser. Raw values are persisted in
/// UserDefaults ("fpc.mode") — don't rename cases.
enum CardMode: String, CaseIterable {
    case classic
    case moment
    case bubble
    case spectrum
    case journal
}

/// One generated color card: a photo plus its derived palette and caption.
struct ColorCard: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var timeText: String
    var createdAt: Date
    var imageFileName: String
    /// Paired Live Photo video, when the source was a Live Photo.
    var videoFileName: String?
    var background: RGBAColor
    var accent: RGBAColor
    var palette: [RGBAColor]
    /// Vertical crop position of the photo inside its fixed slot, normalized
    /// -1 (show top) ... 1 (show bottom); nil/0 = centered. Optional so cards
    /// saved before this field decode fine.
    var photoPanY: Double?
    /// EXIF camera details for the Moment Card metadata block. Optional so
    /// cards saved before this field decode fine.
    var camera: CameraInfo?
    /// The photo's capture moment (EXIF, or import time). Lets the displayed
    /// time re-format when the 12/24h setting changes; older cards without it
    /// fall back to the stored `timeText`.
    var captureDate: Date?
    /// User-dragged Bubble Stamp positions, keyed by palette index, in unit
    /// space. Missing entries fall back to the deterministic scatter.
    var bubblePositions: [Int: NormalizedPoint]?

    init(id: UUID = UUID(),
         title: String,
         timeText: String,
         createdAt: Date = .now,
         imageFileName: String,
         videoFileName: String? = nil,
         background: RGBAColor,
         accent: RGBAColor,
         palette: [RGBAColor],
         camera: CameraInfo? = nil,
         captureDate: Date? = nil) {
        self.id = id
        self.title = title
        self.timeText = timeText
        self.createdAt = createdAt
        self.imageFileName = imageFileName
        self.videoFileName = videoFileName
        self.background = background
        self.accent = accent
        self.palette = palette
        self.camera = camera
        self.captureDate = captureDate
    }
}

/// Card time honoring the 12/24h preference. Formatting happens at render
/// time so flipping the setting restyles every card that has a captureDate.
enum CardTime {
    private static let h24: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let h12: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    static func text(for card: ColorCard, use24h: Bool) -> String {
        guard let date = card.captureDate else { return card.timeText }
        return (use24h ? h24 : h12).string(from: date)
    }
}
