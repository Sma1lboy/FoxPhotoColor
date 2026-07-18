import SwiftUI
import UIKit

/// UIActivityViewController wrapper — export needs no photo-library permission.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// The exported poster is the whole displayed screen, wallpaper-style (per
/// the reference's downloads): canvas wash, brand top bar with glass buttons,
/// and the card exactly as shown. CardView's frozen-size layout means passing
/// the poster size reproduces the on-screen composition at any export ratio.
struct PosterView: View {
    let card: ColorCard
    let image: UIImage
    let size: CGSize
    var showsPaletteStrip = false
    /// Poster style — mirrors the browser's CardMode so the export is
    /// what-you-see-is-what-you-share.
    var mode: CardMode = .moment

    var body: some View {
        ZStack {
            CanvasBackground(color: card.background)

            modeContent

            // Chrome sits ABOVE the mode content so full-bleed styles
            // (bubble, spectrum) still carry the brand mark.
            VStack {
                HStack(spacing: 9) {
                    Text(verbatim: "FoxPhotoColor")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(chromeColor)
                    Spacer()
                    posterButton("plus")
                    posterButton("arrow.down.to.line")
                    posterButton("gearshape")
                }
                .padding(.leading, 16)
                .padding(.trailing, 15)
                .padding(.top, 66)
                Spacer()
            }

            if showsPaletteStrip, card.palette.count > 1 {
                VStack {
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(Array(card.palette.prefix(6).enumerated()), id: \.offset) { _, swatch in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(swatch.color)
                                .frame(height: 26)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, size.height * 0.045)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder private var modeContent: some View {
        switch mode {
        case .moment:
            CardView(card: card, image: image, screenSize: size)
        case .bubble:
            BubbleStampView(card: card, image: image)
        case .floating:
            FloatingBubblesView(card: card, image: image, flatChrome: true)
        case .spectrum:
            SpectrumWallpaperView(card: card)
        case .journal:
            MagicJournalView(card: card, image: image)
        }
    }

    private var chromeIsDark: Bool { card.background.isLight }
    private var chromeColor: Color { chromeIsDark ? .black.opacity(0.75) : .white }

    /// ImageRenderer can't rasterize system materials, so the poster's buttons
    /// use a flat translucent fill with the same top-lit rim as GlassCircle.
    private func posterButton(_ systemName: String) -> some View {
        let rim: Color = chromeIsDark ? .black : .white
        return Image(systemName: systemName)
            .font(.system(size: 19, weight: .light))
            .foregroundStyle(chromeColor)
            .frame(width: 46, height: 46)
            .background(Circle().fill(rim.opacity(0.10)))
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(colors: [rim.opacity(0.55), rim.opacity(0.08)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            )
    }
}

/// Renders a card as a full-resolution poster image for export.
enum CardPosterRenderer {
    @MainActor
    static func render(card: ColorCard,
                       image: UIImage,
                       ratio: PosterRatio = .phone,
                       showPaletteStrip: Bool = false,
                       mode: CardMode = .moment) -> UIImage {
        let size = ratio.size
        let poster = PosterView(card: card, image: image, size: size,
                                showsPaletteStrip: showPaletteStrip,
                                mode: mode)

        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage ?? image
    }
}
