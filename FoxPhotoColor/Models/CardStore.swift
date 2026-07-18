import SwiftUI
import ImageIO

/// Persists cards as JSON + JPEGs under Documents/FoxPhotoColor.
@MainActor
final class CardStore: ObservableObject {
    @Published private(set) var cards: [ColorCard] = []
    /// User-facing error, surfaced as an alert by HomeView.
    @Published var errorMessage: String?

    private let directory: URL
    private let indexURL: URL
    /// Display-sized images only; NSCache evicts under memory pressure.
    private let imageCache = NSCache<NSUUID, UIImage>()
    private static let displayMaxPixel: CGFloat = 1600

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = docs.appendingPathComponent("FoxPhotoColor", isDirectory: true)
        indexURL = directory.appendingPathComponent("cards.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        imageCache.countLimit = 12
        load()
    }

    func card(id: UUID?) -> ColorCard? {
        guard let id else { return nil }
        return cards.first { $0.id == id }
    }

    @discardableResult
    func add(image: UIImage, title: String, timeText: String, palette: ExtractedPalette) -> ColorCard? {
        let fileName = UUID().uuidString + ".jpg"
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            errorMessage = String(localized: "error.import_failed")
            return nil
        }
        do {
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        } catch {
            errorMessage = String(localized: "error.import_failed")
            return nil
        }
        let card = ColorCard(title: title,
                             timeText: timeText,
                             imageFileName: fileName,
                             background: palette.background,
                             accent: palette.accent,
                             palette: palette.swatches)
        if let display = Self.downsample(data: data) {
            imageCache.setObject(display, forKey: card.id as NSUUID)
        }
        cards.insert(card, at: 0)
        persist()
        return card
    }

    func update(_ card: ColorCard) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[idx] = card
        persist()
    }

    // MARK: - Delete with undo (agency: forgiveness over confirmation dialogs)

    struct PendingDelete {
        let card: ColorCard
        let index: Int
    }

    @Published private(set) var pendingDelete: PendingDelete?
    private var purgeTask: Task<Void, Never>?

    /// Removes the card from the list but keeps its file for a few seconds so
    /// the user can undo; the previous pending delete (if any) is purged first.
    func softDelete(_ card: ColorCard) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        purgePendingDelete()
        cards.remove(at: idx)
        pendingDelete = PendingDelete(card: card, index: idx)
        persist()
        purgeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.purgePendingDelete()
        }
    }

    func undoDelete() {
        purgeTask?.cancel()
        purgeTask = nil
        guard let pending = pendingDelete else { return }
        pendingDelete = nil
        cards.insert(pending.card, at: min(pending.index, cards.count))
        persist()
    }

    func purgePendingDelete() {
        purgeTask?.cancel()
        purgeTask = nil
        guard let pending = pendingDelete else { return }
        pendingDelete = nil
        imageCache.removeObject(forKey: pending.card.id as NSUUID)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(pending.card.imageFileName))
    }

    /// Display-sized image (≤1600px long edge) for on-screen cards.
    func image(for card: ColorCard) -> UIImage? {
        if let cached = imageCache.object(forKey: card.id as NSUUID) { return cached }
        let url = directory.appendingPathComponent(card.imageFileName)
        guard let image = Self.downsample(url: url) else { return nil }
        imageCache.setObject(image, forKey: card.id as NSUUID)
        return image
    }

    /// Full-resolution image, uncached — export only.
    func fullImage(for card: ColorCard) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(card.imageFileName).path)
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return }
        do {
            let data = try Data(contentsOf: indexURL)
            cards = try JSONDecoder().decode([ColorCard].self, from: data)
        } catch {
            // Never overwrite a file we couldn't read: move it aside so a later
            // persist() can't destroy the user's library, then surface the error.
            let backup = directory.appendingPathComponent("cards.json.corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: indexURL, to: backup)
            errorMessage = String(localized: "error.load_failed")
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(cards)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            errorMessage = String(localized: "error.save_failed")
        }
    }

    // MARK: - Downsampling (ImageIO — no full decode of the original)

    private static func downsample(url: URL) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return downsample(source: src)
    }

    private static func downsample(data: Data) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return downsample(source: src)
    }

    private static func downsample(source: CGImageSource) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: displayMaxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}
