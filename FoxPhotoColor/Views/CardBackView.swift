import SwiftUI

/// The card's back — its "color dossier": title, an AI one-line color story,
/// and the six swatches as rows (hex + RGB, tap to copy). Reached by
/// double-tapping any card; double-tap again to flip back.
struct CardBackView: View {
    let card: ColorCard
    /// nil while the AI story is being generated.
    let story: String?

    private var paper: Color { card.background.canvasDark.color }
    private var ink: Color { card.background.isLight ? .black.opacity(0.8) : .white }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cardWidth = size.width - 30

            VStack(alignment: .leading, spacing: 0) {
                Text(card.title.uppercased())
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(1.5)
                    .lineLimit(2)
                    .padding(.top, 30)
                storyText
                    .padding(.top, 16)
                swatchRows
                    .padding(.top, 24)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 28)
            .foregroundStyle(ink)
            .frame(width: cardWidth)
            .background(paper)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
            .frame(maxWidth: .infinity)
            .padding(.top, size.height * 0.155)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder private var storyText: some View {
        if let story {
            Text(verbatim: story)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .italic()
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(0.92)
        } else {
            Text("back.story.loading")
                .font(.system(size: 15, design: .serif))
                .italic()
                .opacity(0.5)
        }
    }

    private var swatchRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(card.palette.prefix(6).enumerated()), id: \.offset) { index, swatch in
                Button {
                    UIPasteboard.general.string = swatch.hexString
                    Haptics.light()
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(swatch.color)
                            .frame(width: 34, height: 34)
                        Text(swatch.hexString)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        Spacer()
                        Text(verbatim: rgbText(swatch))
                            .font(.system(size: 12, design: .monospaced))
                            .opacity(0.55)
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .opacity(0.4)
                    }
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text(verbatim: swatch.hexString))
                .accessibilityHint(Text("back.copy.a11y"))
                if index < min(card.palette.count, 6) - 1 {
                    Rectangle()
                        .fill(ink.opacity(0.10))
                        .frame(height: 0.5)
                }
            }
        }
    }

    private func rgbText(_ swatch: RGBAColor) -> String {
        "\(Int((swatch.r * 255).rounded())) \(Int((swatch.g * 255).rounded())) \(Int((swatch.b * 255).rounded()))"
    }
}
