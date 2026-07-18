import SwiftUI
import PhotosUI

struct HomeView: View {
    @EnvironmentObject private var store: CardStore

    @State private var selection: UUID?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showSettings = false
    @State private var shareItem: ShareImage?
    @State private var renameTarget: ColorCard?
    @State private var renameText = ""
    @State private var isImporting = false

    private var currentCard: ColorCard? {
        store.card(id: selection) ?? store.cards.first
    }

    private var backgroundColor: Color {
        currentCard?.background.color ?? EmptyStateView.backgroundBottom
    }

    private var chromeIsDark: Bool {
        currentCard?.background.isLight ?? false
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .animation(.spring(response: 0.5, dampingFraction: 1.0), value: currentCard?.background)

            if store.cards.isEmpty {
                EmptyStateView(pickerItem: $pickerItem)
            } else {
                TabView(selection: $selection) {
                    ForEach(store.cards) { card in
                        CardView(card: card, image: store.image(for: card))
                            .tag(Optional(card.id))
                            .contextMenu {
                                Button {
                                    beginRename(card)
                                } label: {
                                    Label("action.rename", systemImage: "pencil")
                                }
                                Button {
                                    export(card)
                                } label: {
                                    Label("action.export", systemImage: "square.and.arrow.up")
                                }
                                Button(role: .destructive) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) {
                                        store.delete(card)
                                    }
                                } label: {
                                    Label("action.delete", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                beginRename(card)
                            }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
            }

            if isImporting {
                ProgressView()
                    .controlSize(.large)
                    .tint(chromeIsDark ? Color.black.opacity(0.6) : .white)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            importPhoto(newItem)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image])
        }
        .alert("rename.message", isPresented: renameBinding) {
            TextField("rename.placeholder", text: $renameText)
            Button("action.cancel", role: .cancel) { renameTarget = nil }
            Button("action.done") { commitRename() }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Text(verbatim: "FoxPhotoColor")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(chromeForeground)
            Spacer()
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                chromeIcon("plus")
            }
            if let card = currentCard {
                Button {
                    export(card)
                } label: {
                    chromeIcon("arrow.down.to.line")
                }
            }
            Button {
                showSettings = true
            } label: {
                chromeIcon("gearshape")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var chromeForeground: Color {
        chromeIsDark ? Color.black.opacity(0.75) : .white
    }

    private func chromeIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(chromeForeground)
            .frame(width: 38, height: 38)
            .background(
                Circle()
                    .fill(chromeIsDark ? Color.black.opacity(0.08) : Color.white.opacity(0.16))
            )
            .contentShape(Circle())
    }

    // MARK: - Actions

    private func importPhoto(_ item: PhotosPickerItem) {
        isImporting = true
        Task {
            defer {
                isImporting = false
                pickerItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            let palette = await Task.detached(priority: .userInitiated) {
                PaletteExtractor.extract(from: image)
            }.value
            let timeText = Date.now.formatted(date: .omitted, time: .shortened)
            let title = String(localized: "card.default_title")
            withAnimation(.spring(response: 0.5, dampingFraction: 1.0)) {
                if let card = store.add(image: image, title: title, timeText: timeText, palette: palette) {
                    selection = card.id
                }
            }
        }
    }

    private func export(_ card: ColorCard) {
        guard let image = store.image(for: card) else { return }
        let poster = CardPosterRenderer.render(card: card, image: image)
        shareItem = ShareImage(image: poster)
    }

    private func beginRename(_ card: ColorCard) {
        renameText = card.title
        renameTarget = card
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
    }

    private func commitRename() {
        guard var card = renameTarget else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            card.title = trimmed
            store.update(card)
        }
        renameTarget = nil
    }
}

struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
