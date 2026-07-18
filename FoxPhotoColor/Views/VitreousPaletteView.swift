import SwiftUI

/// Vitreous Palette mode (reference IMG_2547): the photo sits as a big
/// rounded card on the canvas — no title zone — with a frosted glass panel
/// floating over its lower half, holding the six extracted colors as circles
/// with hex labels. Tapping a circle recolors the canvas to that swatch.
struct VitreousPaletteView: View {
    let card: ColorCard
    let image: UIImage?
    /// ImageRenderer can't rasterize materials — exports use a flat fill.
    var flatChrome = false
    var onSelectColor: (RGBAColor) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cardWidth = size.width - 30

            ZStack {
                photoCard(width: cardWidth, size: size)
                panel(width: cardWidth - 30)
                    .position(x: size.width / 2, y: size.height * 0.555)
            }
        }
        .ignoresSafeArea()
    }

    private func photoCard(width: CGFloat, size: CGSize) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                card.background.color
            }
        }
        .frame(width: width, height: size.height * 0.565)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .position(x: size.width / 2, y: size.height * 0.165 + size.height * 0.565 / 2)
        .accessibilityHidden(true)
    }

    /// 2×3 grid of palette swatches on frosted glass.
    private func panel(width: CGFloat) -> some View {
        let swatches = Array(card.palette.prefix(6))
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 15) {
            ForEach(Array(swatches.enumerated()), id: \.offset) { _, swatch in
                Button {
                    onSelectColor(swatch)
                } label: {
                    VStack(spacing: 7) {
                        Circle()
                            .fill(swatch.color)
                            .frame(width: 56, height: 56)
                        Text(swatch.hexString)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: swatch.hexString))
                .accessibilityHint(Text("card.recolor.a11y"))
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 18)
        .frame(width: width)
        .modifier(GlassPanel(flat: flatChrome))
        .environment(\.colorScheme, .light)
    }
}

/// Liquid Glass panel on iOS 26; flat fill for exports; material otherwise.
private struct GlassPanel: ViewModifier {
    let flat: Bool
    func body(content: Content) -> some View {
        if flat {
            content.background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.28)))
        } else {
            content.fpcGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
