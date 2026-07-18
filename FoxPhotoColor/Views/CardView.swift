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
            // Fixed card composition: top at 17% of the screen, a 24.9%-of-
            // screen title zone, a 39%-of-screen photo slot — and the card
            // ENDS at the photo's bottom edge (no colored zone below it).
            // Photos aspect-fill and center-crop into the slot, so the card
            // footprint never changes with the photo's aspect ratio.
            let cardWidth = geo.size.width - 30
            let cardTop = geo.size.height * 0.17
            let titleZone = geo.size.height * 0.249
            let photoHeight = geo.size.height * 0.39

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
            .frame(maxWidth: .infinity)
            .task(id: card.videoFileName) {
                guard let loadLivePhoto else { return }
                livePhoto = await loadLivePhoto()
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

