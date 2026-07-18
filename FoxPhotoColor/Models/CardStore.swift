import SwiftUI
import ImageIO
import Photos
import WidgetKit

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
    /// Small grid thumbnails — separate cache so grid scrolling never evicts
    /// the pager's display images.
    private let thumbCache = NSCache<NSUUID, UIImage>()
    private let livePhotoCache = NSCache<NSUUID, PHLivePhoto>()
    private static let displayMaxPixel: CGFloat = 1600
    private static let thumbMaxPixel: CGFloat = 360

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = docs.appendingPathComponent("FoxPhotoColor", isDirectory: true)
        indexURL = directory.appendingPathComponent("cards.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        imageCache.countLimit = 12
        thumbCache.countLimit = 80
        load()
        sweepOrphans()
    }

    func card(id: UUID?) -> ColorCard? {
        guard let id else { return nil }
        return cards.first { $0.id == id }
    }

    @discardableResult
    func add(image: UIImage,
             originalData: Data? = nil,
             title: String, timeText: String, palette: ExtractedPalette,
             camera: CameraInfo? = nil) -> ColorCard? {
        // Persist the ORIGINAL bytes when available: re-encoding via jpegData
        // strips EXIF and the Apple content identifier that pairs a Live
        // Photo's still with its video — without it, post-relaunch rebuild fails.
        let data: Data
        let ext: String
        if let originalData {
            data = originalData
            ext = Self.isHEIC(originalData) ? "heic" : "jpg"
        } else if let encoded = image.jpegData(compressionQuality: 0.92) {
            data = encoded
            ext = "jpg"
        } else {
            errorMessage = String(localized: "error.import_failed")
            return nil
        }
        let fileName = UUID().uuidString + "." + ext
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
                             palette: palette.swatches,
                             camera: camera)
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
        livePhotoCache.removeObject(forKey: pending.card.id as NSUUID)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(pending.card.imageFileName))
        if let video = pending.card.videoFileName {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(video))
        }
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

    /// Grid-sized thumbnail (≤360px long edge).
    func thumbnail(for card: ColorCard) -> UIImage? {
        if let cached = thumbCache.object(forKey: card.id as NSUUID) { return cached }
        let url = directory.appendingPathComponent(card.imageFileName)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = Self.downsample(source: src, maxPixel: Self.thumbMaxPixel) else { return nil }
        thumbCache.setObject(image, forKey: card.id as NSUUID)
        return image
    }

    private static func isHEIC(_ data: Data) -> Bool {
        // ISO-BMFF: 'ftyp' at offset 4, brand starting with 'hei'/'mif'
        guard data.count > 12 else { return false }
        return data[4...7].elementsEqual("ftyp".utf8)
    }

    // MARK: - Live Photo

    /// Persist the paired video of a picker-provided Live Photo so playback
    /// survives relaunch; the card gains videoFileName once the copy lands.
    func attachLivePhoto(_ livePhoto: PHLivePhoto, to card: ColorCard) {
        livePhotoCache.setObject(livePhoto, forKey: card.id as NSUUID)
        let resources = PHAssetResource.assetResources(for: livePhoto)
        guard let paired = resources.first(where: { $0.type == .pairedVideo }) else { return }
        let name = card.id.uuidString + ".mov"
        let url = directory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        PHAssetResourceManager.default().writeData(for: paired, toFile: url, options: nil) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                guard error == nil else {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                if var fresh = self.card(id: card.id) {
                    fresh.videoFileName = name
                    self.update(fresh)
                } else if let pending = self.pendingDelete, pending.card.id == card.id {
                    // Card is inside the undo window; keep the pending copy in
                    // sync so an undo restores the video too (and a purge
                    // cleans the .mov up).
                    var updated = pending.card
                    updated.videoFileName = name
                    self.pendingDelete = PendingDelete(card: updated, index: pending.index)
                } else {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    /// Rebuild a playable PHLivePhoto from the persisted still + paired video.
    func loadLivePhoto(for card: ColorCard) async -> PHLivePhoto? {
        if let cached = livePhotoCache.object(forKey: card.id as NSUUID) { return cached }
        guard let videoFileName = card.videoFileName else { return nil }
        let videoURL = directory.appendingPathComponent(videoFileName)
        let imageURL = directory.appendingPathComponent(card.imageFileName)
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return nil }
        let photo: PHLivePhoto? = await withCheckedContinuation { continuation in
            var resumed = false
            PHLivePhoto.request(withResourceFileURLs: [imageURL, videoURL],
                                placeholderImage: nil,
                                targetSize: .zero,
                                contentMode: .aspectFit) { photo, info in
                // The callback fires again with the full-quality photo; resume
                // only once, skipping the degraded pass when a final follows.
                let degraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
                guard !degraded, !resumed else { return }
                resumed = true
                continuation.resume(returning: photo)
            }
        }
        if let photo {
            livePhotoCache.setObject(photo, forKey: card.id as NSUUID)
        }
        return photo
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

    /// Delete files no card references — e.g. an app kill during the 5s undo
    /// window leaves the purged card's .jpg/.mov behind.
    private func sweepOrphans() {
        let referenced = Set(cards.flatMap { [$0.imageFileName, $0.videoFileName].compactMap { $0 } })
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in contents where !referenced.contains(file) && !file.hasPrefix("cards.json") {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
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
        publishWidgetSnapshot()
    }

    // MARK: - Widget snapshot (App Group)

    private static let appGroupID = "group.me.sma1lboy.foxphotocolor"

    private struct WidgetSnapshot: Codable {
        var title: String
        var timeText: String
        var bg: RGBAColor
        var accent: RGBAColor
    }

    /// Latest card → shared container, so the widget can render it.
    /// No-ops when the app group container is unavailable (e.g. unsigned builds).
    private func publishWidgetSnapshot() {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID) else { return }
        let jsonURL = container.appendingPathComponent("widget-card.json")
        let thumbURL = container.appendingPathComponent("widget-thumb.jpg")
        if let card = cards.first {
            let snapshot = WidgetSnapshot(title: card.title, timeText: card.timeText,
                                          bg: card.background, accent: card.accent)
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: jsonURL, options: .atomic)
            }
            if let thumb = thumbnail(for: card),
               let jpeg = thumb.jpegData(compressionQuality: 0.8) {
                try? jpeg.write(to: thumbURL, options: .atomic)
            }
        } else {
            try? FileManager.default.removeItem(at: jsonURL)
            try? FileManager.default.removeItem(at: thumbURL)
        }
        WidgetCenter.shared.reloadAllTimelines()
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

    private static func downsample(source: CGImageSource, maxPixel: CGFloat = displayMaxPixel) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}
