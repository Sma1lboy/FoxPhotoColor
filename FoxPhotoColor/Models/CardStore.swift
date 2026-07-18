import SwiftUI

/// Persists cards as JSON + JPEGs under Documents/FoxPhotoColor.
@MainActor
final class CardStore: ObservableObject {
    @Published private(set) var cards: [ColorCard] = []

    private let directory: URL
    private let indexURL: URL
    private var imageCache: [UUID: UIImage] = [:]

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = docs.appendingPathComponent("FoxPhotoColor", isDirectory: true)
        indexURL = directory.appendingPathComponent("cards.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    func card(id: UUID?) -> ColorCard? {
        guard let id else { return nil }
        return cards.first { $0.id == id }
    }

    @discardableResult
    func add(image: UIImage, title: String, timeText: String, palette: ExtractedPalette) -> ColorCard? {
        let fileName = UUID().uuidString + ".jpg"
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        do {
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        } catch {
            return nil
        }
        let card = ColorCard(title: title,
                             timeText: timeText,
                             imageFileName: fileName,
                             background: palette.background,
                             accent: palette.accent,
                             palette: palette.swatches)
        imageCache[card.id] = image
        cards.insert(card, at: 0)
        persist()
        return card
    }

    func update(_ card: ColorCard) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[idx] = card
        persist()
    }

    func delete(_ card: ColorCard) {
        cards.removeAll { $0.id == card.id }
        imageCache[card.id] = nil
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(card.imageFileName))
        persist()
    }

    func image(for card: ColorCard) -> UIImage? {
        if let cached = imageCache[card.id] { return cached }
        let url = directory.appendingPathComponent(card.imageFileName)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache[card.id] = image
        return image
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([ColorCard].self, from: data) else { return }
        cards = decoded
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(cards) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
