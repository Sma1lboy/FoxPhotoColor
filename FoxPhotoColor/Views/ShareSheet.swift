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

/// Renders a card as a full-resolution poster image for export.
enum CardPosterRenderer {
    @MainActor
    static func render(card: ColorCard, image: UIImage) -> UIImage {
        let size = CGSize(width: 430, height: 932) // iPhone poster canvas, @3x below
        let poster = ZStack {
            card.background.color
            CardView(card: card, image: image)
        }
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage ?? image
    }
}
