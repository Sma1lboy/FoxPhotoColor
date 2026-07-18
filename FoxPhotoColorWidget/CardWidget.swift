import WidgetKit
import SwiftUI
import UIKit

// Mirrors the app's snapshot schema (kept tiny on purpose; the widget target
// doesn't link the app's model files).
struct WidgetRGBA: Codable {
    var r: Double
    var g: Double
    var b: Double
    var color: Color { Color(red: r, green: g, blue: b) }
}

struct WidgetSnapshot: Codable {
    var title: String
    var timeText: String
    var bg: WidgetRGBA
    var accent: WidgetRGBA
    /// Deep-link target; optional so pre-R13 snapshots still decode.
    var id: UUID?
}

private let appGroupID = "group.me.sma1lboy.foxphotocolor"

struct CardEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let thumbnail: UIImage?
}

struct CardProvider: TimelineProvider {
    func placeholder(in context: Context) -> CardEntry {
        CardEntry(date: .now, snapshot: nil, thumbnail: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CardEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CardEntry>) -> Void) {
        // The app pushes reloadAllTimelines() on every change; no self-refresh.
        completion(Timeline(entries: [load()], policy: .never))
    }

    private func load() -> CardEntry {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID) else {
            return CardEntry(date: .now, snapshot: nil, thumbnail: nil)
        }
        let snapshot = (try? Data(contentsOf: container.appendingPathComponent("widget-card.json")))
            .flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }
        let thumb = UIImage(contentsOfFile: container.appendingPathComponent("widget-thumb.jpg").path)
        return CardEntry(date: .now, snapshot: snapshot, thumbnail: thumb)
    }
}

struct CardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CardEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if family == .accessoryRectangular {
                    lockScreenCard(snapshot)
                } else {
                    card(snapshot)
                }
            } else {
                emptyState
            }
        }
        .widgetURL(deepLink)
        .containerBackground(entry.snapshot?.bg.color ?? Color(red: 0.42, green: 0.53, blue: 0.33),
                             for: .widget)
    }

    /// Tapping any family opens the exact card the widget shows.
    private var deepLink: URL? {
        guard let id = entry.snapshot?.id else { return nil }
        return URL(string: "foxphotocolor://card/\(id.uuidString)")
    }

    /// Lock screen: vibrant material renders the text; no colors of our own.
    private func lockScreenCard(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.title.uppercased())
                .font(.system(size: 13, weight: .heavy))
                .tracking(0.8)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(snapshot.timeText.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .opacity(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card(_ snapshot: WidgetSnapshot) -> some View {
        VStack(spacing: family == .systemSmall ? 5 : 8) {
            Text(snapshot.title.uppercased())
                .font(.system(size: family == .systemSmall ? 10 : 12, weight: .heavy))
                .tracking(1.6)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Text(snapshot.timeText.uppercased())
                .font(.system(size: family == .systemSmall ? 8 : 9, weight: .semibold))
                .tracking(1.2)
                .opacity(0.85)
            if let thumbnail = entry.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: family == .systemSmall ? 52 : 76)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .foregroundStyle(snapshot.accent.color)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "swatchpalette")
                .font(.system(size: 20))
            Text("widget.empty")
                .font(.system(size: 10, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.9))
    }
}

struct CardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FoxPhotoColorCard", provider: CardProvider()) { entry in
            CardWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.name")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct FoxPhotoColorWidgetBundle: WidgetBundle {
    var body: some Widget {
        CardWidget()
    }
}
