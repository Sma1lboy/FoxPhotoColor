import SwiftUI

/// The poster layout: letterspaced title high on the card, photo just below
/// center, generous colored margins all around — matching the reference cards.
struct CardView: View {
    let card: ColorCard
    let image: UIImage?
    /// On-screen only; the exported poster stays clean.
    var onSwatchTap: ((RGBAColor) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            // ponytail: fixed point sizes are deliberate here — this is a poster
            // artifact whose composition must match its exported image, not a
            // text document; Dynamic Type applies to the app chrome instead.
            VStack(spacing: 0) {
                VStack(spacing: 9) {
                    Text(card.title.uppercased())
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(3.0)
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                    Text(card.timeText.uppercased())
                        .font(.system(size: 10.5, weight: .semibold))
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
            .overlay(alignment: .bottom) {
                if let onSwatchTap, card.palette.count > 1 {
                    SwatchRow(card: card, onTap: onSwatchTap)
                        .padding(.bottom, 30)
                }
            }
        }
    }
}

/// Tappable palette dots: pick any extracted color as the card's background.
private struct SwatchRow: View {
    let card: ColorCard
    let onTap: (RGBAColor) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(card.palette.prefix(6).enumerated()), id: \.offset) { _, swatch in
                Button {
                    onTap(swatch)
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 15, height: 15)
                        .overlay(
                            Circle().strokeBorder(
                                card.accent.color.opacity(isCurrent(swatch) ? 0.9 : 0.25),
                                lineWidth: isCurrent(swatch) ? 2 : 1)
                        )
                        .padding(4) // generous hit area
                        .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .accessibilityLabel(Text("swatch.row.a11y"))
    }

    private func isCurrent(_ swatch: RGBAColor) -> Bool {
        // The background is a muted derivation of its source swatch, so compare
        // through the same derivation.
        PaletteExtractor.rederive(from: swatch, palette: card.palette).background == card.background
    }
}
