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
    @State private var exportTarget: ColorCard?
    @State private var dragOffset: CGFloat = 0
    @State private var dragAxis: DragAxis = .undetermined

    private enum DragAxis { case undetermined, vertical, horizontal }

    @ScaledMetric(relativeTo: .headline) private var brandSize: CGFloat = 19

    private var currentCard: ColorCard? {
        store.card(id: selection) ?? store.cards.first
    }

    private var backgroundColor: Color {
        currentCard?.background.color ?? EmptyStateView.backgroundBottom
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
            backgroundColor
                .ignoresSafeArea()
                .animation(uiAnimation, value: currentCard?.background)

            if store.cards.isEmpty {
                EmptyStateView(pickerItem: $pickerItem)
            } else {
                TabView(selection: $selection) {
                    ForEach(store.cards) { card in
                        let isCurrent = (selection ?? store.cards.first?.id) == card.id
                        CardView(card: card,
                                 image: store.image(for: card),
                                 onSwatchTap: { swatch in recolor(card, with: swatch) },
                                 loadLivePhoto: { await store.loadLivePhoto(for: card) },
                                 onTitleTap: { beginRename(card) },
                                 onExport: { export(card) },
                                 onDelete: { deleteCard(card) })
                            .offset(y: isCurrent ? dragOffset : 0)
                            .opacity(isCurrent ? Double(1 - min(0.35, max(0, -dragOffset) / 900)) : 1)
                            .simultaneousGesture(dismissGesture(for: card))
                            .tag(Optional(card.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
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
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            importPhoto(newItem)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showGrid) {
            GridOverviewView { card in
                selection = card.id
            }
            .environmentObject(store)
        }
        .sheet(item: $exportTarget) { card in
            if let image = store.fullImage(for: card) ?? store.image(for: card) {
                ExportOptionsView(card: card, image: image)
            }
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
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Text(verbatim: "FoxPhotoColor")
                .font(.system(size: brandSize, weight: .bold))
                .foregroundStyle(chromeForeground)
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
            // Real material chrome (skill §12), not a flat tint — adapts with
            // the per-card color scheme.
            .background(.ultraThinMaterial, in: Circle())
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
                  let image = UIImage(data: data) else {
                // Realistic path: iCloud-offloaded photo picked while offline.
                store.errorMessage = String(localized: "error.import_failed")
                return
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
                                        title: title, timeText: timeText, palette: palette) {
                    selection = card.id
                    newCard = card
                }
            }
            if newCard != nil {
                Haptics.success()
            }
            // The card is on screen — release the spinner before the slow tails
            // (Live Photo video fetch, geocode) instead of at closure exit.
            isImporting = false
            pickerItem = nil
            // Live Photos carry a paired video; fetch it AFTER the card is
            // visible (it can be an iCloud download) and attach when it lands.
            if let created = newCard,
               let livePhoto = try? await item.loadTransferable(type: PHLivePhoto.self) {
                store.attachLivePhoto(livePhoto, to: created)
            }
            // Geocoded place name pops in when the lookup lands. Re-fetch the
            // live card and touch only the title, so a rename or recolor done
            // while the lookup was in flight is never clobbered.
            if let created = newCard, let coordinate = metadata.coordinate,
               let place = await PhotoMetadataParser.placeName(for: coordinate),
               var fresh = store.card(id: created.id), fresh.title == title {
                fresh.title = place
                withAnimation(uiAnimation) {
                    store.update(fresh)
                }
            }
        }
    }

    private func export(_ card: ColorCard) {
        guard store.fullImage(for: card) ?? store.image(for: card) != nil else {
            store.errorMessage = String(localized: "error.export_failed")
            return
        }
        exportTarget = card
    }

    // MARK: - Fluid dismiss (skill §2/§3/§5/§6/§9: 1:1 tracking, interruptible,
    // velocity handoff, momentum projection, rubber-band)

    private func dismissGesture(for card: ColorCard) -> some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { value in
                guard (selection ?? store.cards.first?.id) == card.id else { return }
                // Lock to an axis on first movement so horizontal paging wins
                // cleanly when the user is swiping between cards.
                if dragAxis == .undetermined {
                    dragAxis = abs(value.translation.width) > abs(value.translation.height)
                        ? .horizontal : .vertical
                }
                guard dragAxis == .vertical else { return }
                let dy = value.translation.height
                dragOffset = dy < 0 ? dy : Self.rubberband(dy, dimension: 320)
            }
            .onEnded { value in
                let axis = dragAxis
                dragAxis = .undetermined
                guard axis == .vertical else { return }
                let velocity = value.velocity.height
                let projected = dragOffset + Self.project(velocity)
                let commitThreshold = -UIScreen.main.bounds.height * 0.32
                if projected < commitThreshold, store.cards.count >= 1 {
                    commitDismiss(card, velocity: velocity)
                } else {
                    // Hand the release velocity into the snap-back too (skill
                    // §5) — a plain spring here would hard-cut the finger's
                    // momentum ("brick wall").
                    let relativeVelocity = dragOffset != 0
                        ? Double(velocity / (0 - dragOffset)) : 0
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2)
                                               : .interpolatingSpring(stiffness: 260, damping: 32,
                                                                      initialVelocity: relativeVelocity)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func commitDismiss(_ card: ColorCard, velocity: CGFloat) {
        let target = -UIScreen.main.bounds.height * 1.1
        // Hand the gesture's velocity to the spring so there is no seam
        // between the finger and the animation.
        let relativeVelocity = Double(velocity / (target - dragOffset))
        let fling: Animation = reduceMotion
            ? .easeOut(duration: 0.18)
            : .interpolatingSpring(stiffness: 180, damping: 26, initialVelocity: relativeVelocity)
        Haptics.medium()
        withAnimation(fling) {
            dragOffset = target
        }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 180 : 230))
            deleteCard(card)
            dragOffset = 0
        }
    }

    /// Apple's momentum projection (deceleration ≈ 0.998).
    private static func project(_ velocity: CGFloat, decelerationRate: CGFloat = 0.998) -> CGFloat {
        (velocity / 1000) * decelerationRate / (1 - decelerationRate)
    }

    /// Progressive resistance past a boundary (skill §9).
    private static func rubberband(_ overshoot: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
        (overshoot * dimension * constant) / (dimension + constant * abs(overshoot))
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
            // Sits above the swatch row so the two never overlap.
            .padding(.bottom, 96)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
