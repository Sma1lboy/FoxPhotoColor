import SwiftUI

/// Bubble Stamp mode: the photo runs full-bleed and the extracted palette
/// floats over it as organic bubbles — each one breathing (PebbleShape) and
/// drifting slowly. Bubbles are draggable; a dragged position persists on the
/// card (normalized), everything else uses the deterministic scatter.
struct BubbleStampView: View {
    let card: ColorCard
    let image: UIImage?
    /// ImageRenderer can't rasterize system materials — exports pass true to
    /// swap the stamp's material for a flat translucent fill.
    var flatChrome = false
    var onTitleTap: () -> Void = {}
    /// Called when a bubble drag ends, with its palette index and new
    /// normalized position. nil = read-only (export rendering).
    var onMoveBubble: ((Int, NormalizedPoint) -> Void)?

    @AppStorage("fpc.use24HourTime") private var use24HourTime = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragIndex: Int?
    @State private var dragTranslation: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let placed = Self.layout(for: card, in: size)
            // ONE flat ZStack inside the timeline: every positioned child
            // (photo, bubbles, stamp) shares the identical coordinate space —
            // nested containers earned us subtle per-child origin drift.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                ZStack {
                    photo(size: size)
                    // VoiceOver: bubbles are decorative/draggable eye-candy;
                    // the stamp below carries the card's spoken identity.
                    ForEach(0..<placed.count, id: \.self) { index in
                        bubbleView(placed[index], index: index, time: t, size: size)
                    }
                    .accessibilityHidden(true)
                    stamp(size: size)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .ignoresSafeArea()
    }

    private func bubbleView(_ bubble: Bubble, index: Int, time: Double, size: CGSize) -> some View {
        let dragging = dragIndex == index
        // A held bubble stops breathing-drifting and follows the finger 1:1.
        let phase: Double = time + Double(index) * 1.7
        let x: CGFloat = bubble.center.x + (dragging ? dragTranslation.width : drift(phase, 0))
        let y: CGFloat = bubble.center.y + (dragging ? dragTranslation.height : drift(phase, 1.3))
        return PebbleShape(phase: dragging ? 0 : phase)
            .fill(bubble.color)
            // Hairline rim keeps a bubble legible when it floats over a
            // photo region of its own color (palette colors come FROM the
            // photo, so camouflage is common).
            .overlay(
                PebbleShape(phase: dragging ? 0 : phase)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1.2)
            )
            .frame(width: bubble.diameter, height: bubble.diameter * 0.92)
            .scaleEffect(dragging ? 1.12 : 1)
            .position(x: x, y: y)
            .shadow(color: .black.opacity(dragging ? 0.30 : 0.18),
                    radius: dragging ? 14 : 8, y: dragging ? 8 : 4)
            .gesture(dragGesture(for: bubble, index: index, size: size))
            .animation(.spring(response: 0.3, dampingFraction: 1.0), value: dragging)
    }

    private func dragGesture(for bubble: Bubble, index: Int, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard onMoveBubble != nil else { return }
                dragIndex = index
                dragTranslation = value.translation
            }
            .onEnded { value in
                defer { dragIndex = nil; dragTranslation = .zero }
                guard let onMoveBubble else { return }
                let x = min(max(bubble.center.x + value.translation.width,
                                size.width * 0.08), size.width * 0.92)
                let y = min(max(bubble.center.y + value.translation.height,
                                size.height * 0.08), size.height * 0.80)
                Haptics.light()
                onMoveBubble(index, NormalizedPoint(x: x / size.width, y: y / size.height))
            }
    }

    /// Slow figure-eight drift, ±7pt. Frozen at phase-dependent rest under
    /// Reduce Motion (TimelineView is paused, so this stays constant).
    private func drift(_ phase: Double, _ offset: Double) -> CGFloat {
        CGFloat(sin(phase * 0.35 + offset) * 7.0)
    }

    private func photo(size: CGSize) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                card.background.color
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    struct Bubble {
        let color: Color
        let diameter: CGFloat
        let center: CGPoint

        /// Generous hit area (min 44pt) for drag targeting.
        var hitFrame: CGRect {
            let side = max(diameter, 44)
            return CGRect(x: center.x - side / 2, y: center.y - side / 2,
                          width: side, height: side)
        }
    }

    /// Deterministic scatter (LCG seeded from the card's UUID), overridden by
    /// any user-dragged positions stored on the card. Shared with HomeView's
    /// gesture arbitration — keep it pure.
    static func layout(for card: ColorCard, in size: CGSize) -> [Bubble] {
        var state = UInt64(truncatingIfNeeded: card.id.uuidString.hashValue) | 1
        func random() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 33) / Double(UInt32.max)
        }
        let colors = Array(card.palette.prefix(6))
        return colors.enumerated().map { index, swatch in
            // Grid-ish columns with jitter. Jitter (±0.05w) plus the max
            // radius sum (88pt) stays inside the 0.33w column pitch, so two
            // bubbles can kiss but never merge.
            let column = Double(index % 3), rowBand = Double(index / 3)
            let x = (0.16 + column * 0.33 + (random() - 0.5) * 0.10) * size.width
            let y = (0.24 + rowBand * 0.34 + (random() - 0.5) * 0.16) * size.height
            let diameter = CGFloat(50 + random() * 38)
            // Hard bounds: bubbles never kiss the screen edges or the stamp.
            var center = CGPoint(x: min(max(x, size.width * 0.10), size.width * 0.90),
                                 y: min(max(y, size.height * 0.10), size.height * 0.72))
            if let stored = card.bubblePositions?[index] {
                center = CGPoint(x: stored.x * size.width, y: stored.y * size.height)
            }
            if ProcessInfo.processInfo.environment["FPC_DEBUG"] == "1" {
                print("FPC_DEBUG bubble idx=\(index) size=\(size) center=\(center) stored=\(String(describing: card.bubblePositions?[index]))")
            }
            return Bubble(color: swatch.color, diameter: diameter, center: center)
        }
    }

    /// Title + time stamp in a glass capsule, pinned near the bottom.
    private func stamp(size: CGSize) -> some View {
        VStack(spacing: 3) {
            Text(card.title.uppercased())
                .font(.system(size: 13, weight: .heavy))
                .tracking(1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(CardTime.text(for: card, use24h: use24HourTime).uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(2)
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background {
            if flatChrome {
                Capsule().fill(Color.black.opacity(0.32))
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .environment(\.colorScheme, .dark)
        .position(x: size.width / 2, y: size.height * 0.88)
        .onTapGesture { onTitleTap() }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("card.rename.a11y"))
    }
}
