import SwiftUI
import PhotosUI

struct HomeView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: UUID?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showSettings = false
    @State private var showGrid = false
    @State private var renameTarget: ColorCard?
    @State private var renameText = ""
    @State private var isImporting = false
    @State private var shareImage: ShareImage?
    @State private var dragAxis: DragAxis = .undetermined
    @State private var panPreview: CGFloat = 0

    @AppStorage("fpc.mode") private var modeRaw = CardMode.moment.rawValue
    @AppStorage("fpc.alwaysPoeticTitle") private var alwaysPoeticTitle = false
    @AppStorage("fpc.livePhotoEnabled") private var livePhotoEnabled = true

    private var mode: CardMode { CardMode(rawValue: modeRaw) ?? .moment }

    /// iPad: the poster canvas caps at 560pt and centers, keeping the phone
    /// proportions instead of stretching. Phones pass through unchanged.
    private static let maxCanvasWidth: CGFloat = 560

    private var canvasSize: CGSize {
        let bounds = UIScreen.main.bounds.size
        return CGSize(width: min(bounds.width, Self.maxCanvasWidth), height: bounds.height)
    }

    /// Gesture hit-rects computed in canvas space, shifted into screen space.
    private func inScreenSpace(_ rect: CGRect) -> CGRect {
        let inset = max(0, (UIScreen.main.bounds.width - canvasSize.width) / 2)
        return rect.offsetBy(dx: inset, dy: 0)
    }

    private enum DragAxis { case undetermined, vertical, horizontal, pan, inert }

    @ScaledMetric(relativeTo: .headline) private var brandSize: CGFloat = 21

    private var currentCard: ColorCard? {
        store.card(id: selection) ?? store.cards.first
    }

    private var chromeIsDark: Bool {
        currentCard?.background.isLight ?? false
    }

    /// Reduced-motion users get a short cross-fade instead of springs (skill §14).
    private var uiAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 1.0)
    }

    var body: some View {
        ZStack {
            Group {
                if let card = currentCard {
                    CanvasBackground(color: card.background)
                } else {
                    EmptyStateView.backgroundGradient
                }
            }
            .ignoresSafeArea()
            .animation(uiAnimation, value: currentCard?.background)

            if store.cards.isEmpty {
                EmptyStateView(pickerItem: $pickerItem)
            } else {
                TabView(selection: $selection) {
                    ForEach(store.cards) { card in
                        let isCurrent = (selection ?? store.cards.first?.id) == card.id
                        Group {
                            switch mode {
                            case .vitreous:
                                VitreousPaletteView(card: card,
                                                    image: store.image(for: card),
                                                    onSelectColor: { recolor(card, with: $0) })
                            case .bubble:
                                BubbleStampView(card: card,
                                               image: store.image(for: card),
                                               onCycleColor: { cycleColor(card) },
                                               onTitleTap: { beginRename(card) })
                            case .floating:
                                FloatingBubblesView(card: card,
                                                image: store.image(for: card),
                                                onTitleTap: { beginRename(card) },
                                                onMoveBubble: { index, point in
                                                    moveBubble(card, index: index, to: point)
                                                })
                            case .spectrum:
                                SpectrumWallpaperView(card: card,
                                                      onTitleTap: { beginRename(card) })
                            case .journal:
                                MagicJournalView(card: card,
                                                 image: store.image(for: card),
                                                 onCycleColor: { cycleColor(card) },
                                                 onTitleTap: { beginRename(card) })
                            case .moment:
                                CardView(card: card,
                                         image: store.image(for: card),
                                         screenSize: canvasSize,
                                         panPreview: isCurrent ? panPreview : 0,
                                         onCycleColor: { cycleColor(card) },
                                         loadLivePhoto: { await store.loadLivePhoto(for: card) },
                                         onTitleTap: { beginRename(card) },
                                         onExport: { export(card) },
                                         onDelete: { deleteCard(card) })
                            }
                        }
                            // Reference proportions are fractions of the full
                            // screen — let each page's geometry span it. On
                            // iPad the canvas caps at 560pt and centers.
                            .frame(maxWidth: Self.maxCanvasWidth)
                            .frame(maxWidth: .infinity)
                            .ignoresSafeArea()
                            .simultaneousGesture(panGesture(for: card))
                            .tag(Optional(card.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }

            // The reference onboarding screen is chrome-free; the bar belongs
            // to the card browser only.
            if !store.cards.isEmpty {
                VStack {
                    topBar
                    Spacer()
                }
            }

            if store.pendingDelete != nil {
                undoToast
            }

            if isImporting {
                ProgressView()
                    .controlSize(.large)
                    .tint(chromeIsDark ? Color.black.opacity(0.6) : .white)
            }
        }
        .animation(uiAnimation, value: store.pendingDelete?.card.id)
        .onAppear {
            // Seed must run before the QA hooks below can reference cards.
            SampleSeed.seedIfNeeded(into: store)
            // QA harness hooks (headless sims can't tap): FPC_SELECT=<index>
            // jumps to a card; FPC_RECOLOR=<card>:<swatch> exercises the real
            // recolor path so screenshots can verify it.
            let env = ProcessInfo.processInfo.environment
            // FPC_IMPORT=<path>: run the real import pipeline on an image file
            // (QA: PhotosPicker can't be tapped headlessly).
            if let path = env["FPC_IMPORT"],
               let data = FileManager.default.contents(atPath: path) {
                Task { await importData(data) }
            }
            if let raw = env["FPC_SELECT"],
               let idx = Int(raw), store.cards.indices.contains(idx) {
                selection = store.cards[idx].id
            }
            if let raw = env["FPC_RECOLOR"] {
                let parts = raw.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2, store.cards.indices.contains(parts[0]) {
                    let card = store.cards[parts[0]]
                    if card.palette.indices.contains(parts[1]) {
                        selection = card.id
                        recolor(card, with: card.palette[parts[1]])
                    }
                }
            }
            // FPC_PAN=<index>:<-1..1> sets a card's photo crop position.
            if let raw = env["FPC_PAN"] {
                let parts = raw.split(separator: ":")
                if parts.count == 2, let idx = Int(parts[0]), let v = Double(parts[1]),
                   store.cards.indices.contains(idx) {
                    var card = store.cards[idx]
                    card.photoPanY = min(max(v, -1), 1)
                    selection = card.id
                    store.update(card)
                }
            }
            if let raw = env["FPC_DELETE"],
               let idx = Int(raw), store.cards.indices.contains(idx) {
                deleteCard(store.cards[idx])
            }
            if env["FPC_EXPORT"] == "1", let card = store.cards.first {
                export(card)
            }
            if env["FPC_GRID"] == "1" {
                showGrid = true
            }
            if env["FPC_SETTINGS"] == "1" {
                showSettings = true
            }
            // FPC_MODE=moment|bubble|floating|spectrum|journal forces a style.
            if let raw = env["FPC_MODE"], CardMode(rawValue: raw) != nil {
                modeRaw = raw
            }
            // FPC_CLEAR=1: exercise the real clear-all path headlessly.
            if env["FPC_CLEAR"] == "1" {
                store.removeAll()
            }
            // FPC_BUBBLE=<card>:<idx>:<x>:<y> — exercise the bubble-move
            // persistence path (drags can't be simulated headlessly).
            if let raw = env["FPC_BUBBLE"] {
                let parts = raw.split(separator: ":")
                if parts.count == 4, let cardIdx = Int(parts[0]), let idx = Int(parts[1]),
                   let x = Double(parts[2]), let y = Double(parts[3]),
                   store.cards.indices.contains(cardIdx) {
                    selection = store.cards[cardIdx].id
                    moveBubble(store.cards[cardIdx], index: idx,
                               to: NormalizedPoint(x: x, y: y))
                }
            }
            backfillMissingTitles()
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            importPhoto(newItem)
        }
        // Widget deep link: foxphotocolor://card/<uuid> jumps to that card.
        .onOpenURL { url in
            if ProcessInfo.processInfo.environment["FPC_DEBUG"] == "1" {
                print("FPC_DEBUG onOpenURL \(url) host=\(url.host() ?? "nil") last=\(url.lastPathComponent)")
            }
            guard url.scheme == "foxphotocolor", url.host() == "card",
                  let id = UUID(uuidString: url.lastPathComponent),
                  store.cards.contains(where: { $0.id == id }) else { return }
            showSettings = false
            showGrid = false
            withAnimation(uiAnimation) {
                selection = id
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showGrid) {
            GridOverviewView { card in
                selection = card.id
            }
            .environmentObject(store)
        }
        .sheet(item: $shareImage) { item in
            ShareSheet(items: [item.image])
        }
        .alert("rename.message", isPresented: renameBinding) {
            TextField("rename.placeholder", text: $renameText)
            Button("action.cancel", role: .cancel) { renameTarget = nil }
            Button("action.done") { commitRename() }
        }
        .alert("error.title", isPresented: errorBinding) {
            Button("action.ok", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(verbatim: store.errorMessage ?? "")
        }
        // Dark backgrounds want a light status bar and vice versa; under the
        // SwiftUI lifecycle preferredColorScheme is what drives it.
        .preferredColorScheme(chromeIsDark ? .light : .dark)
        // The reference app runs with the status bar hidden — the poster owns
        // the whole screen.
        .statusBarHidden(true)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 9) {
            Text(verbatim: "FoxPhotoColor")
                .font(.system(size: brandSize, weight: .bold))
                .foregroundStyle(chromeForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            if store.cards.count > 1 {
                Button {
                    showGrid = true
                } label: {
                    chromeIcon("square.grid.2x2")
                }
            }
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
        .padding(.leading, 16)
        .padding(.trailing, 15)
        .padding(.top, 12)
    }

    private var chromeForeground: Color {
        chromeIsDark ? Color.black.opacity(0.75) : .white
    }

    private func chromeIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 19, weight: .light))
            .foregroundStyle(chromeForeground)
            .frame(width: 46, height: 46)
            .background(GlassCircle(isDark: chromeIsDark))
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
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                // Realistic path: iCloud-offloaded photo picked while offline.
                store.errorMessage = String(localized: "error.import_failed")
                return
            }
            let created = await importData(data)
            isImporting = false
            pickerItem = nil
            // Live Photos carry a paired video; fetch it AFTER the card is
            // visible (it can be an iCloud download) and attach when it lands.
            // Gated by the settings toggle — off means stills only.
            if livePhotoEnabled, let created,
               let livePhoto = try? await item.loadTransferable(type: PHLivePhoto.self) {
                store.attachLivePhoto(livePhoto, to: created)
            }
        }
    }

    /// The shared import pipeline: palette + EXIF off-main, card insert,
    /// then async geocode backfill. Returns the created card.
    @discardableResult
    private func importData(_ data: Data) async -> ColorCard? {
        guard let image = UIImage(data: data) else {
            store.errorMessage = String(localized: "error.import_failed")
            return nil
        }
        let (palette, metadata) = await Task.detached(priority: .userInitiated) {
            (PaletteExtractor.extract(from: image), PhotoMetadataParser.parse(from: data))
        }.value
        let captureDate = metadata.creationDate ?? .now
        let timeText = captureDate.formatted(date: .omitted, time: .shortened)
        let title = String(localized: "card.default_title")
        var newCard: ColorCard?
        withAnimation(uiAnimation) {
            if let card = store.add(image: image, originalData: data,
                                    title: title, timeText: timeText, palette: palette,
                                    camera: metadata.camera,
                                    captureDate: captureDate) {
                selection = card.id
                newCard = card
            }
        }
        guard let created = newCard else { return nil }
        Haptics.success()
        // Title backfill, best source first: GPS place name → AI poetic title
        // (local CPA vision call) → keep the default. Re-fetch the live card
        // and touch only the title, so a rename or recolor done while the
        // lookup was in flight is never clobbered.
        Task {
            var newTitle: String?
            // "Always poetic" setting: skip the place name and let the AI title
            // win even when GPS is present (mirrors the reference's toggle).
            if !alwaysPoeticTitle, let coordinate = metadata.coordinate {
                newTitle = await PhotoMetadataParser.placeName(for: coordinate)
            }
            if newTitle == nil {
                newTitle = await AITitle.poeticTitle(for: image)
            }
            if let newTitle,
               var fresh = store.card(id: created.id), fresh.title == title {
                fresh.title = newTitle
                withAnimation(uiAnimation) {
                    store.update(fresh)
                }
            }
        }
        return created
    }

    /// Cards stuck with the default title (AI/geocode were unreachable at
    /// import) get one more AI attempt per launch — never touches renamed cards.
    private func backfillMissingTitles() {
        let defaultTitle = String(localized: "card.default_title")
        for card in store.cards where card.title == defaultTitle {
            Task {
                if let image = store.image(for: card),
                   let title = await AITitle.poeticTitle(for: image),
                   var fresh = store.card(id: card.id), fresh.title == defaultTitle {
                    fresh.title = title
                    withAnimation(uiAnimation) {
                        store.update(fresh)
                    }
                }
            }
        }
    }

    private func moveBubble(_ card: ColorCard, index: Int, to point: NormalizedPoint) {
        var updated = card
        var positions = updated.bubblePositions ?? [:]
        positions[index] = point
        updated.bubblePositions = positions
        store.update(updated)
    }

    /// Download taps skip any options page (reference behavior): render the
    /// card exactly as displayed — current mode, screen proportions — and go
    /// straight to the share sheet.
    private func export(_ card: ColorCard) {
        guard let image = store.fullImage(for: card) ?? store.image(for: card) else {
            store.errorMessage = String(localized: "error.export_failed")
            return
        }
        let poster = CardPosterRenderer.render(card: card, image: image,
                                               ratio: .phone, mode: mode)
        Haptics.light()
        shareImage = ShareImage(image: poster)
    }

    // MARK: - Photo crop pan (the ONLY vertical drag on a card; the reference
    // has no swipe-to-delete — deletion lives in the long-press menu)

    private func panGesture(for card: ColorCard) -> some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { value in
                guard (selection ?? store.cards.first?.id) == card.id else { return }
                // Lock to an axis on first movement so horizontal paging wins
                // cleanly. A vertical drag starting on an overflowing photo
                // repositions its crop; anywhere else it does nothing.
                if dragAxis == .undetermined {
                    // A drag starting on a bubble belongs to the bubble —
                    // neither dismiss nor paging should fight it.
                    if mode == .floating,
                       FloatingBubblesView.layout(for: card, in: canvasSize)
                           .contains(where: { inScreenSpace($0.hitFrame).contains(value.startLocation) }) {
                        dragAxis = .inert
                    } else if abs(value.translation.width) > abs(value.translation.height) {
                        dragAxis = .horizontal
                    } else if mode == .moment,
                              inScreenSpace(CardView.photoRect(in: canvasSize))
                                .contains(value.startLocation),
                              CardView.panOverflow(image: store.image(for: card),
                                                   screenSize: canvasSize) > 0 {
                        dragAxis = .pan
                    } else {
                        dragAxis = .vertical
                    }
                }
                if dragAxis == .pan {
                    panPreview = value.translation.height
                }
            }
            .onEnded { value in
                let axis = dragAxis
                dragAxis = .undetermined
                if axis == .pan {
                    commitPan(card, translation: value.translation.height)
                }
            }
    }

    /// Fold the drag into the card's stored crop position (normalized -1...1)
    /// so the reposition persists — and exports exactly as shown.
    private func commitPan(_ card: ColorCard, translation: CGFloat) {
        let overflow = CardView.panOverflow(image: store.image(for: card),
                                            screenSize: canvasSize)
        panPreview = 0
        guard overflow > 0 else { return }
        var updated = card
        let base = CGFloat(card.photoPanY ?? 0)
        updated.photoPanY = Double(min(max(base + translation / (overflow / 2), -1), 1))
        store.update(updated)
    }

    private var undoToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 14) {
                Text("toast.deleted")
                    .font(.system(size: 14, weight: .medium))
                Button {
                    guard store.pendingDelete != nil else { return }
                    Haptics.success()
                    withAnimation(uiAnimation) {
                        store.undoDelete()
                    }
                } label: {
                    Text("action.undo")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            // Dark material capsule (skill §12) — forced dark so the white
            // text stays legible over any card color.
            .background(.regularMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Reference behavior: tapping the colored zone advances the background
    /// through the extracted palette.
    private func cycleColor(_ card: ColorCard) {
        let palette = Array(card.palette.prefix(6))
        guard palette.count > 1 else { return }
        let currentIndex = palette.firstIndex {
            PaletteExtractor.rederive(from: $0, palette: card.palette).background == card.background
        } ?? -1
        recolor(card, with: palette[(currentIndex + 1) % palette.count])
    }

    private func recolor(_ card: ColorCard, with swatch: RGBAColor) {
        var updated = card
        let derived = PaletteExtractor.rederive(from: swatch, palette: card.palette)
        updated.background = derived.background
        updated.accent = derived.accent
        Haptics.light()
        withAnimation(uiAnimation) {
            store.update(updated)
        }
    }

    private func deleteCard(_ card: ColorCard) {
        // Reassign selection before removal so the TabView never points at a
        // tag that no longer exists.
        if selection == card.id || selection == nil {
            let remaining = store.cards.filter { $0.id != card.id }
            let oldIndex = store.cards.firstIndex(where: { $0.id == card.id }) ?? 0
            selection = remaining.indices.contains(oldIndex) ? remaining[oldIndex].id : remaining.last?.id
        }
        withAnimation(uiAnimation) {
            store.softDelete(card)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } })
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
