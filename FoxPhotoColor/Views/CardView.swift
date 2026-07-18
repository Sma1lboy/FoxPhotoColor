import SwiftUI

/// The poster layout: letterspaced title high on the card, photo just below
/// center, generous colored margins all around — matching the reference cards.
struct CardView: View {
    let card: ColorCard
    let image: UIImage?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Text(card.title.uppercased())
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(3.2)
                        .multilineTextAlignment(.center)
                    Text(card.timeText.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2.4)
                        .opacity(0.85)
                }
                .foregroundStyle(card.accent.color)
                .padding(.horizontal, 36)
                .frame(height: geo.size.height * 0.34)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width - 48,
                               maxHeight: geo.size.height * 0.42)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
