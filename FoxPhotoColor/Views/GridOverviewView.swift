import SwiftUI

/// All cards at a glance: two-column grid of mini posters. Tap to jump.
struct GridOverviewView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ColorCard) -> Void

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.cards) { card in
                        Button {
                            onSelect(card)
                            dismiss()
                        } label: {
                            miniCard(card)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(16)
            }
            .navigationTitle("grid.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
        }
    }

    private func miniCard(_ card: ColorCard) -> some View {
        VStack(spacing: 6) {
            // Grid cells are wayfinding chrome, not poster artifacts: one
            // legible title line, no 7pt caption.
            Text(card.title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.4)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(card.accent.color)
                .padding(.horizontal, 10)
                .padding(.top, 18)

            Spacer(minLength: 8)
            if let image = store.thumbnail(for: card) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 1))
                    .padding(.horizontal, 14)
            }
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.62, contentMode: .fit)
        .background(RoundedRectangle(cornerRadius: 12).fill(card.background.color))
        .accessibilityLabel(Text(verbatim: card.title))
    }
}
