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

/// The exported poster is the CARD itself, full-bleed (not the whole screen):
/// title zone on the card color, photo slot with aspect-fill crop, and a
/// color strip at the bottom — same composition as the on-screen card.
struct PosterView: View {
    let card: ColorCard
    let image: UIImage
    var showsPaletteStrip = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(spacing: 13) {
                    Text(card.title.uppercased())
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(3.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .opacity(0.92)
                    Text(card.timeText.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(2.2)
                        .opacity(0.85)
                }
                .foregroundStyle(card.accent.color)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .frame(height: geo.size.height * 0.33)
                Spacer(minLength: 0)

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height * 0.67)
                    .clipped()
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(card.background.color)
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
                    .padding(.bottom, geo.size.height * 0.045)
                }
            }
        }
    }
}

/// Renders a card as a full-resolution poster image for export.
enum CardPosterRenderer {
    @MainActor
    static func render(card: ColorCard,
                       image: UIImage,
                       ratio: PosterRatio = .phone,
                       showPaletteStrip: Bool = false) -> UIImage {
        let size = ratio.size
        let poster = PosterView(card: card, image: image, showsPaletteStrip: showPaletteStrip)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage ?? image
    }
}
