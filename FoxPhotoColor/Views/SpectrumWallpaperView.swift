import SwiftUI

/// Spectrum Wallpaper mode: no photo — the palette itself becomes a
/// full-screen gradient wallpaper, brightest color at the top, with the
/// title/time signed at the bottom like a print mark.
struct SpectrumWallpaperView: View {
    let card: ColorCard
    @AppStorage("fpc.use24HourTime") private var use24HourTime = true
    var onTitleTap: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: sortedColors, startPoint: .top, endPoint: .bottom)
                signature
                    .padding(.leading, 28)
                    .padding(.bottom, 46)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    /// Brightest → darkest keeps the sky-to-ground read of a wallpaper.
    private var sortedColors: [Color] {
        let swatches = card.palette.isEmpty ? [card.background] : Array(card.palette.prefix(6))
        return swatches.sorted { $0.luminance > $1.luminance }.map(\.color)
    }

    private var signature: some View {
        // The bottom of the gradient is the darkest swatch — ink follows it.
        let darkest = card.palette.min(by: { $0.luminance < $1.luminance })
        let ink: Color = (darkest?.isLight ?? false) ? .black.opacity(0.7) : .white
        return VStack(alignment: .leading, spacing: 4) {
            Text(card.title.uppercased())
                .font(.system(size: 14, weight: .heavy))
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .onTapGesture { onTitleTap() }
                .accessibilityLabel(Text(verbatim: card.title))
                .accessibilityHint(Text("card.rename.a11y"))
            Text(CardTime.text(for: card, use24h: use24HourTime).uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(2.5)
                .opacity(0.75)
        }
        .foregroundStyle(ink)
    }
}
