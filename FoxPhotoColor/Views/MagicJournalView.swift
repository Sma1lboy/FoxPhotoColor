import SwiftUI

/// Magic Journal mode: a scrapbook page — paper card, date header, the photo
/// taped in at a slight tilt with a white print border, serif caption, and a
/// row of palette swatch dots.
struct MagicJournalView: View {
    let card: ColorCard
    @AppStorage("fpc.use24HourTime") private var use24HourTime = true
    let image: UIImage?
    var onCycleColor: () -> Void = {}
    var onTitleTap: () -> Void = {}

    private static let paper = Color(red: 0.965, green: 0.949, blue: 0.918)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let pageWidth = size.width - 30

            VStack(alignment: .leading, spacing: 0) {
                dateHeader
                    .padding(.horizontal, 26)
                    .padding(.top, 24)
                tiltedPhoto(width: pageWidth - 76,
                            maxHeight: size.height * 0.42)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                caption
                    .padding(.horizontal, 26)
                    .padding(.top, 22)
                    .padding(.bottom, 30)
            }
            .frame(width: pageWidth)
            .background(Self.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .contentShape(Rectangle())
            .onTapGesture { onCycleColor() }
            .accessibilityHint(Text("card.recolor.a11y"))
            .frame(maxWidth: .infinity)
            .padding(.top, size.height * 0.16)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var ink: Color { card.accent.color }

    private var dateHeader: some View {
        HStack {
            Text(card.createdAt.formatted(.dateTime.month(.wide).day().year())
                .uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(2.5)
            Spacer()
            Text(CardTime.text(for: card, use24h: use24HourTime).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .opacity(0.7)
        }
        .foregroundStyle(ink)
    }

    private func tiltedPhoto(width: CGFloat, maxHeight: CGFloat) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                card.background.color
            }
        }
        .frame(width: width, height: min(width * 0.78, maxHeight))
        .clipped()
        .padding(9)
        .background(Color.white)
        .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
        .rotationEffect(.degrees(-1.8))
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(card.title)
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .onTapGesture { onTitleTap() }
                .accessibilityHint(Text("card.rename.a11y"))
            HStack(spacing: 10) {
                ForEach(Array(card.palette.prefix(6).enumerated()), id: \.offset) { _, swatch in
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 13, height: 13)
                }
            }
            .accessibilityHidden(true)
        }
    }
}
