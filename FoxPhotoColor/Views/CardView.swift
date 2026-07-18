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
    let image: UIImage?
    /// Tap on the colored zone (outside the title) cycles the background
    /// through the palette; on-screen only.
    var onCycleColor: (() -> Void)? = nil
    /// Export option: flat strip of the extracted palette near the bottom.
    var showsPaletteStrip: Bool = false
    /// Async Live Photo loader; nil in export/poster contexts.
    var loadLivePhoto: (() async -> PHLivePhoto?)? = nil
    /// Title-block actions (rename on tap, menu on long-press); nil in export.
    var onTitleTap: (() -> Void)? = nil
    var onExport: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var livePhoto: PHLivePhoto?
    @State private var playToken = 0

    var body: some View {
        GeometryReader { geo in
            // Reference proportions (measured off IMG_2531/2532): a fixed-
            // footprint card — top at 17% of the screen, 15pt side and bottom
            // margins. Inside: a 24.9%-of-screen title zone, then the photo
            // full-width at natural aspect with its own soft corners, then the
            // card color continues to the card's bottom edge. Photos taller
            // than the remaining space are center-cropped (aspect fill).
            let cardWidth = geo.size.width - 30
            let cardTop = geo.size.height * 0.17
            let cardHeight = geo.size.height - cardTop - 15
            let titleZone = geo.size.height * 0.249
            let photoHeight = photoHeight(cardWidth: cardWidth,
                                          minHeight: geo.size.height * 0.22,
                                          maxHeight: cardHeight - titleZone)

            VStack(spacing: 0) {
                Spacer().frame(height: cardTop)

                VStack(spacing: 0) {
                    titleBlock
                        .frame(width: cardWidth, height: titleZone)
                    photoView(width: cardWidth, height: photoHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Spacer(minLength: 0)
                }
                .frame(width: cardWidth, height: cardHeight)
                .background(card.background.color)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .task(id: card.videoFileName) {
                guard let loadLivePhoto else { return }
                livePhoto = await loadLivePhoto()
            }
            .overlay(alignment: .bottom) {
                if showsPaletteStrip, card.palette.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(Array(card.palette.prefix(6).enumerated()), id: \.offset) { _, swatch in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(swatch.color)
                                .frame(height: 26)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geo.size.height * 0.05)
                }
            }
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
            Text(card.timeText.uppercased())
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

    @ViewBuilder
    private func photoView(width: CGFloat, height: CGFloat) -> some View {
        if let image {
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

    /// Photo fills the card's width at its natural aspect ratio, clamped so
    /// panoramas and portraits both keep a poster-like card.
    private func photoHeight(cardWidth: CGFloat, minHeight: CGFloat, maxHeight: CGFloat) -> CGFloat {
        guard let image, image.size.width > 0 else { return (minHeight + maxHeight) / 2 }
        let natural = cardWidth * image.size.height / image.size.width
        return min(max(natural, minHeight), maxHeight)
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

