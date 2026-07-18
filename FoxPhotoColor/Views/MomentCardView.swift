import SwiftUI

/// Moment Card mode: a polaroid-style print — warm-white card, inset photo,
/// organic accent blob, then title / time / capture metadata, all pulled from
/// the card's EXIF `CameraInfo`. Layout mirrors the PhotoColors reference
/// (IMG_2549): card at 16% screen height, 15pt side margins, bottom ≈ 72.5%.
struct MomentCardView: View {
    let card: ColorCard
    let image: UIImage?
    var onCycleColor: () -> Void = {}
    var onTitleTap: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let paper = Color(red: 0.976, green: 0.965, blue: 0.945)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cardWidth = size.width - 30

            // The polaroid hugs its content: photo + caption + border padding.
            VStack(alignment: .leading, spacing: 0) {
                photo(width: cardWidth - 28)
                    .padding(14)
                caption
                    .padding(.horizontal, 26)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
            }
            .frame(width: cardWidth)
            .background(Self.paper)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .contentShape(Rectangle())
            .onTapGesture { onCycleColor() }
            .frame(maxWidth: .infinity)
            .padding(.top, size.height * 0.155)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func photo(width: CGFloat) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                card.background.color
            }
        }
        .frame(width: width, height: width)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var caption: some View {
        HStack(alignment: .center, spacing: 22) {
            // The reference's bubble is alive — a slow organic breathe.
            // Static under Reduce Motion (skill §14).
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
                PebbleShape(phase: ctx.date.timeIntervalSinceReferenceDate)
                    .fill(card.accent.color)
            }
            .frame(width: 64, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(card.title.uppercased())
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .onTapGesture { onTitleTap() }
                Text(card.timeText.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .padding(.bottom, 3)
                ForEach(metadataLines, id: \.self) { line in
                    Text(line.uppercased())
                        .font(.system(size: 6.8, weight: .semibold))
                        .tracking(0.4)
                        .opacity(0.62)
                }
            }
            .foregroundStyle(card.accent.color)
            Spacer(minLength: 0)
        }
    }

    /// The reference's capture-metadata block; each line renders only when
    /// its EXIF field survived import.
    private var metadataLines: [String] {
        guard let camera = card.camera else { return [] }
        var lines: [String] = []
        if let model = camera.model {
            lines.append(String(format: String(localized: "moment.captured_with"), model))
        }
        if let altitude = camera.altitude {
            lines.append(String(format: String(localized: "moment.altitude"),
                                String(Int(altitude.rounded()))))
        }
        if let heading = camera.headingDegrees {
            lines.append(String(format: String(localized: "moment.facing"),
                                Self.compassName(for: heading)))
        }
        var settings: [String] = []
        if let f = camera.fNumber { settings.append(String(format: "f/%.1f", f)) }
        if let exposure = camera.exposureSeconds, exposure > 0 {
            settings.append(exposure < 1
                ? "1/\(Int((1 / exposure).rounded()))s"
                : String(format: "%.1fs", exposure))
        }
        if let iso = camera.iso { settings.append("ISO \(iso)") }
        if !settings.isEmpty {
            lines.append(String(format: String(localized: "moment.settings"),
                                settings.joined(separator: " · ")))
        }
        return lines
    }

    private static func compassName(for degrees: Double) -> String {
        let keys = ["direction.n", "direction.ne", "direction.e", "direction.se",
                    "direction.s", "direction.sw", "direction.w", "direction.nw"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360)
                .truncatingRemainder(dividingBy: 360) + 22.5) / 45) % 8
        return String(localized: String.LocalizationValue(keys[index]))
    }
}

/// Irregular pebble — the organic color blob on the polaroid caption.
/// `phase` breathes each vertex radius with out-of-phase sines, so the blob
/// slowly morphs instead of pulsing uniformly. phase = 0 gives the rest shape.
struct PebbleShape: Shape {
    var phase: Double = 0

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2, ry = rect.height / 2
        // Static asymmetry (a pebble at rest, not an ellipse) + slow wobble.
        let base: [Double] = [1.00, 0.94, 1.03, 0.97, 1.02, 0.92]
        let n = base.count
        var points: [CGPoint] = []
        points.reserveCapacity(n)
        for i in 0..<n {
            let angle: Double = Double(i) / Double(n) * 2.0 * Double.pi - Double.pi / 2.0
            let wobble: Double = 1.0 + 0.08 * sin(phase * 0.9 + Double(i) * 2.1)
            let r: Double = base[i] * wobble
            let x: CGFloat = center.x + rx * CGFloat(r * cos(angle))
            let y: CGFloat = center.y + ry * CGFloat(r * sin(angle))
            points.append(CGPoint(x: x, y: y))
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        var p = Path()
        p.move(to: mid(points[n - 1], points[0]))
        for i in 0..<n {
            p.addQuadCurve(to: mid(points[i], points[(i + 1) % n]), control: points[i])
        }
        p.closeSubpath()
        return p
    }
}
