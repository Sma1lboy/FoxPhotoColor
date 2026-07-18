import SwiftUI

enum PosterRatio: String, CaseIterable, Identifiable {
    case phone   // 9:19.5, full-screen wallpaper style
    case social  // 4:5, feed-friendly

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .phone: CGSize(width: 430, height: 932)
        case .social: CGSize(width: 480, height: 600)
        }
    }

    var labelKey: LocalizedStringKey {
        switch self {
        case .phone: "export.ratio.phone"
        case .social: "export.ratio.social"
        }
    }
}

/// Export style sheet: pick a ratio and whether to include the palette strip,
/// with a live preview of the exact poster that will be shared.
struct ExportOptionsView: View {
    let card: ColorCard
    let image: UIImage

    @Environment(\.dismiss) private var dismiss
    @State private var ratio: PosterRatio = .phone
    @State private var showPaletteStrip = false
    @State private var shareItem: ShareImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview
                    .frame(maxHeight: .infinity)
                    .padding(.top, 8)

                Picker("export.ratio", selection: $ratio) {
                    ForEach(PosterRatio.allCases) { r in
                        Text(r.labelKey).tag(r)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("export.palette_strip", isOn: $showPaletteStrip)
                    .tint(card.background.color)

                Button {
                    let poster = CardPosterRenderer.render(card: card,
                                                          image: image,
                                                          ratio: ratio,
                                                          showPaletteStrip: showPaletteStrip)
                    shareItem = ShareImage(image: poster)
                } label: {
                    Text("action.share")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(card.background.color))
                        .foregroundStyle(card.background.isLight ? Color.black.opacity(0.8) : .white)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .navigationTitle("export.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.image])
            }
        }
        .presentationDetents([.large])
    }

    private var preview: some View {
        GeometryReader { geo in
            let size = ratio.size
            let scale = min(geo.size.width / size.width, geo.size.height / size.height)
            ZStack {
                CanvasBackground(color: card.background)
                CardView(card: card, image: image, showsPaletteStrip: showPaletteStrip)
            }
            .frame(width: size.width, height: size.height)
            .scaleEffect(scale)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 10 / scale))
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            .animation(.spring(response: 0.4, dampingFraction: 1.0), value: ratio)
        }
    }
}
