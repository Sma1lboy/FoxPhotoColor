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
    /// Title-block actions (rename on tap, menu on long-press); nil in export.
    var onTitleTap: (() -> Void)? = nil
    var onExport: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var livePhoto: PHLivePhoto?
    @State private var playToken = 0

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
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                // Spatial mapping: the title block owns rename + card actions;
                // the photo below owns Live Photo playback. No shared owners.
                .onTapGesture { onTitleTap?() }
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

                if let image {
                    Group {
                        if let livePhoto {
                            LivePhotoView(livePhoto: livePhoto, playToken: playToken)
                                .aspectRatio(image.size, contentMode: .fit)
                                .onTapGesture { playToken += 1 } // tap or long-press plays
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
                            // White glyph on a material chip — legible over any
                            // photo corner (skill §12), unlike the accent color.
                            Image(systemName: "livephoto")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(.ultraThinMaterial, in: Circle())
                                .environment(\.colorScheme, .dark)
                                .padding(6)
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

/// PHLivePhotoView wrapper. Built-in long-press playback stays; bumping
/// playToken triggers playback from a SwiftUI tap as well.
private struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    var playToken: Int = 0

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
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
