import SwiftUI
import PhotosUI

/// The poster layout: letterspaced title high on the card, photo just below
/// center, generous colored margins all around — matching the reference cards.
struct CardView: View {
    let card: ColorCard
    let image: UIImage?
    /// On-screen only; the exported poster stays clean unless the user opts
    /// into the flat palette strip below.
    var onSwatchTap: ((RGBAColor) -> Void)? = nil
    /// Export option: flat strip of the extracted palette near the bottom.
    var showsPaletteStrip: Bool = false
    /// Async Live Photo loader; nil in export/poster contexts.
    var loadLivePhoto: (() async -> PHLivePhoto?)? = nil

    @State private var livePhoto: PHLivePhoto?

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
                    Group {
                        if let livePhoto {
                            // Long-press plays; PHLivePhotoView owns the gesture.
                            LivePhotoView(livePhoto: livePhoto)
                                .aspectRatio(image.size, contentMode: .fit)
                        } else {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .frame(maxWidth: geo.size.width - 48,
                           maxHeight: geo.size.height * 0.42)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .overlay(alignment: .topLeading) {
                        if livePhoto != nil {
                            Image(systemName: "livephoto")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(card.accent.color.opacity(0.9))
                                .padding(8)
                                .accessibilityLabel(Text("card.live.a11y"))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .task(id: card.videoFileName) {
                guard let loadLivePhoto else { return }
                livePhoto = await loadLivePhoto()
            }
            .overlay(alignment: .bottom) {
                if let onSwatchTap, card.palette.count > 1 {
                    SwatchRow(card: card, onTap: onSwatchTap)
                        .padding(.bottom, 30)
                } else if showsPaletteStrip, card.palette.count > 1 {
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
}

/// PHLivePhotoView wrapper — long-press playback comes built in.
private struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        view.livePhoto = livePhoto
    }
}

/// Tappable palette dots: pick any extracted color as the card's background.
private struct SwatchRow: View {
    let card: ColorCard
    let onTap: (RGBAColor) -> Void

    var body: some View {
        let swatches = Array(card.palette.prefix(6).enumerated())
        HStack(spacing: 2) {
            ForEach(swatches, id: \.offset) { index, swatch in
                let current = isCurrent(swatch)
                Button {
                    onTap(swatch)
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(width: current ? 19 : 15, height: current ? 19 : 15)
                        .overlay(
                            Circle().strokeBorder(
                                card.accent.color.opacity(current ? 0.9 : 0.25),
                                lineWidth: current ? 2 : 1)
                        )
                        // 44pt HIG-minimum hit target around the small dot
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text(String(format: String(localized: "swatch.item.a11y"),
                                                index + 1, swatches.count)))
                .accessibilityAddTraits(current ? [.isSelected] : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("swatch.row.a11y"))
    }

    private func isCurrent(_ swatch: RGBAColor) -> Bool {
        // The background is a muted derivation of its source swatch, so compare
        // through the same derivation.
        PaletteExtractor.rederive(from: swatch, palette: card.palette).background == card.background
    }
}
