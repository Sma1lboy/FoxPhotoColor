import SwiftUI
import PhotosUI

/// The canvas behind the poster card: a radial wash lit from the top-leading
/// corner — card color lightened there, passing through the card color, and
/// settling slightly darker toward the bottom (measured off the reference).
struct CanvasBackground: View {
    let color: RGBAColor

    var body: some View {
        RadialGradient(stops: [
            .init(color: color.canvasLight.color, location: 0),
            .init(color: color.color, location: 0.44),
            .init(color: color.canvasDark.color, location: 0.75),
        ], center: .topLeading, startRadius: 0, endRadius: 1000)
    }
}

/// The poster: a large continuous-corner card floating on the canvas wash.
/// Title centered in the card's colored zone; the photo runs edge-to-edge to
/// the card's sides and bottom, clipped by the card's corners — matching the
/// reference app exactly.
struct CardView: View {
    let card: ColorCard
    @AppStorage("fpc.use24HourTime") private var use24HourTime = true
    let image: UIImage?
    /// Frozen layout reference. The card's slots are fractions of this, NOT of
    /// a live GeometryReader — during the dismiss drag the safe-area geometry
    /// mutates and a live reader would re-layout the card mid-gesture (photo
    /// visibly lagging the title zone).
    var screenSize: CGSize = UIScreen.main.bounds.size
    /// Live pan preview in points while the user drags the photo (HomeView
    /// owns the gesture); committed into card.photoPanY on release.
    var panPreview: CGFloat = 0
    /// Tap on the colored zone (outside the title) cycles the background
    /// through the palette; on-screen only.
    var onCycleColor: (() -> Void)? = nil
    /// Async Live Photo loader; nil in export/poster contexts.
    var loadLivePhoto: (() async -> PHLivePhoto?)? = nil
    /// Title-block actions (rename on tap, menu on long-press); nil in export.
    var onTitleTap: (() -> Void)? = nil
    var onExport: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var livePhoto: PHLivePhoto?
    @State private var playToken = 0

    var body: some View {
        // Fixed card composition against the frozen screen size: top at 19%,
        // a 22%-of-screen title zone, a 34%-of-screen photo slot — the card
        // ENDS at the photo's bottom edge. Photos aspect-fill and center-crop
        // into the slot, so the footprint never changes with aspect ratio.
        let cardWidth = screenSize.width - 40
        let cardTop = screenSize.height * 0.19
        let titleZone = screenSize.height * 0.22
        let photoHeight = screenSize.height * 0.34

        VStack(spacing: 0) {
            Spacer().frame(height: cardTop)

            VStack(spacing: 0) {
                titleBlock
                    .frame(width: cardWidth, height: titleZone)
                photoView(width: cardWidth, height: photoHeight)
            }
            .frame(width: cardWidth, height: titleZone + photoHeight)
            .background(card.background.color)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: card.videoFileName) {
            guard let loadLivePhoto else { return }
            livePhoto = await loadLivePhoto()
        }
    }

    // ponytail: fixed point sizes are deliberate — this is a poster artifact
    // whose composition must match its exported image; Dynamic Type applies
    // to the app chrome instead.
    private var titleBlock: some View {
        VStack(spacing: 13) {
            Text(card.title.uppercased())
                // Reference metrics ("SINGAPORE" in IMG_2532): 10.3pt cap
                // height ≈ 15pt SF, heavy, wide tracking, one line shrunk to fit.
                .font(.system(size: 15, weight: .heavy))
                .tracking(3.2)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .opacity(0.92)
            Text(CardTime.text(for: card, use24h: use24HourTime).uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(2.2)
                .opacity(0.85)
        }
        .foregroundStyle(card.accent.color)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        // Reference behavior: tapping the colored zone cycles the background
        // through the photo's palette; rename and the rest live in the
        // long-press menu. The photo below owns Live Photo playback.
        .onTapGesture { (onCycleColor ?? onTitleTap)?() }
        .accessibilityHint(Text("card.recolor.a11y"))
        .contextMenu {
            if let onTitleTap {
                Button { onTitleTap() } label: { Label("action.rename", systemImage: "pencil") }
            }
            if let onExport {
                Button { onExport() } label: { Label("action.export", systemImage: "square.and.arrow.up") }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: { Label("action.delete", systemImage: "trash") }
            }
        }
    }

    /// The card's photo slot rect on screen — HomeView uses this to route
    /// vertical drags that start on the photo into repositioning.
    static func photoRect(in screenSize: CGSize) -> CGRect {
        CGRect(x: 20,
               y: screenSize.height * (0.19 + 0.22),
               width: screenSize.width - 40,
               height: screenSize.height * 0.34)
    }

    /// How far (in points) the aspect-filled photo overflows its slot
    /// vertically; the pan range is ±overflow/2 around center.
    static func panOverflow(image: UIImage?, screenSize: CGSize) -> CGFloat {
        guard let image, image.size.width > 0 else { return 0 }
        let slot = photoRect(in: screenSize)
        let natural = slot.width * image.size.height / image.size.width
        return max(0, natural - slot.height)
    }

    @ViewBuilder
    private func photoView(width: CGFloat, height: CGFloat) -> some View {
        if let image {
            let overflow = Self.panOverflow(image: image, screenSize: screenSize)
            let base = CGFloat(card.photoPanY ?? 0) * overflow / 2
            let pan = min(max(base + panPreview, -overflow / 2), overflow / 2)
            Group {
                if let livePhoto {
                    LivePhotoView(livePhoto: livePhoto, playToken: playToken)
                        .onTapGesture { playToken += 1 } // tap or long-press plays
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: width, height: height)
            .offset(y: pan)
            .frame(width: width, height: height)
            .clipped()
            .overlay(alignment: .topLeading) {
                if livePhoto != nil {
                    // White glyph on a material chip — legible over any photo
                    // corner (skill §12).
                    Image(systemName: "livephoto")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.ultraThinMaterial, in: Circle())
                        .environment(\.colorScheme, .dark)
                        .padding(8)
                        .accessibilityLabel(Text("card.live.a11y"))
                }
            }
        }
    }

}

/// PHLivePhotoView wrapper. Built-in long-press playback stays; bumping
/// playToken triggers playback from a SwiftUI tap as well.
private struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    var playToken: Int = 0

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        view.livePhoto = livePhoto
        if context.coordinator.lastToken != playToken {
            context.coordinator.lastToken = playToken
            view.startPlayback(with: .full)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastToken = 0
    }
}

