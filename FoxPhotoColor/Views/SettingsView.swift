import SwiftUI

// 设置页,布局对齐 PhotoColors 参考图(IMG_2542-2547):
// 深色 sheet、置顶居中标题、大写字距 section header、圆角 28 分组卡片、
// 图标行 + 蓝色控件、版本页脚。
struct SettingsView: View {
    // ponytail: 预留偏好,先落 AppStorage,建卡/导出管线接入后即生效
    @AppStorage("fpc.use24HourTime") private var use24HourTime = true
    @AppStorage("fpc.livePhotoEnabled") private var livePhotoEnabled = true
    @AppStorage("fpc.defaultExportAspect") private var defaultExportAspect = "full"
    // 已接线的偏好
    @AppStorage("fpc.mode") private var modeRaw = CardMode.classic.rawValue
    @AppStorage("fpc.alwaysPoeticTitle") private var alwaysPoeticTitle = false

    private enum Metrics {
        static let pageBackground = Color(white: 0.07)
        static let groupBackground = Color(white: 0.125)
        static let secondaryText = Color(white: 0.55)
        static let groupCornerRadius: CGFloat = 28
        static let margin: CGFloat = 20
        static let rowInset: CGFloat = 24
        static let iconWidth: CGFloat = 30
        static let iconGap: CGFloat = 18
        static let separatorInset: CGFloat = 24 + 30 + 18
        static let accent = Color(red: 0.04, green: 0.52, blue: 1.0)
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                modeSection
                cardSection
                exportSection
                tipsSection
                developerSection
                footer
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 40)
        }
        .background(Metrics.pageBackground)
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("settings.title")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 26)
                .padding(.bottom, 18)
                .background(Metrics.pageBackground)
        }
        .presentationDetents([.large])
    }

    // MARK: - Sections

    private var modeSection: some View {
        section(header: "settings.section.mode") {
            modeRow(.classic, icon: "rectangle.portrait",
                    title: "settings.mode.classic",
                    subtitle: "settings.mode.classic.desc")
            separator
            modeRow(.moment, icon: "photo.artframe",
                    title: "settings.mode.moment",
                    subtitle: "settings.mode.moment.desc")
            separator
            row(icon: "sparkles",
                title: "settings.mode.more",
                subtitle: "settings.mode.more.desc",
                dimmed: true) { EmptyView() }
        }
    }

    private func modeRow(_ target: CardMode, icon: String,
                         title: LocalizedStringKey,
                         subtitle: LocalizedStringKey) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                modeRaw = target.rawValue
            }
        } label: {
            row(icon: icon, title: title, subtitle: subtitle) {
                if modeRaw == target.rawValue {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Metrics.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var cardSection: some View {
        section(header: "settings.section.card") {
            infoRow(icon: "hand.tap", text: "settings.card.tip.recolor")
            separator
            row(icon: "clock",
                title: "settings.card.timeformat",
                subtitle: "settings.pref.pending") {
                segmented(options: [(Text(verbatim: "12h"), false), (Text(verbatim: "24h"), true)],
                          selection: $use24HourTime)
            }
            separator
            row(icon: "livephoto",
                title: "settings.card.livephoto",
                subtitle: "settings.pref.pending") {
                Toggle("", isOn: $livePhotoEnabled)
                    .labelsHidden()
                    .tint(Metrics.accent)
            }
            separator
            row(icon: "quote.opening",
                title: "settings.card.poetic",
                subtitle: "settings.card.poetic.desc") {
                Toggle("", isOn: $alwaysPoeticTitle)
                    .labelsHidden()
                    .tint(Metrics.accent)
            }
        }
    }

    private var exportSection: some View {
        section(header: "settings.section.export") {
            row(icon: "aspectratio",
                title: "settings.export.aspect",
                subtitle: "settings.pref.pending") {
                segmented(options: [(Text("settings.export.aspect.full"), "full"),
                                    (Text(verbatim: "4:5"), "4:5")],
                          selection: $defaultExportAspect)
            }
        }
    }

    private var tipsSection: some View {
        section(header: "settings.section.tips") {
            infoRow(icon: "arrow.up.circle", text: "settings.tip.delete")
            separator
            infoRow(icon: "character.cursor.ibeam", text: "settings.tip.rename")
            separator
            infoRow(icon: "livephoto.play", text: "settings.tip.live")
            separator
            infoRow(icon: "square.grid.2x2", text: "settings.tip.grid")
        }
    }

    private var developerSection: some View {
        section(header: "settings.section.developer") {
            Link(destination: URL(string: "https://github.com/Sma1lboy")!) {
                row(icon: "person.crop.circle",
                    title: nil,
                    verbatimTitle: "GitHub @Sma1lboy",
                    subtitle: nil) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(verbatim: "FoxPhotoColor")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            Text("\(Text("settings.version")) \(Text(verbatim: version))")
                .font(.system(size: 15))
                .foregroundStyle(Metrics.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 44)
    }

    // MARK: - Building blocks

    private func section(header: LocalizedStringResource,
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: header).uppercased())
                .font(.system(size: 15, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(Metrics.secondaryText)
                .padding(.leading, Metrics.rowInset)
                .padding(.top, 34)
                .padding(.bottom, 14)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(Metrics.groupBackground)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.groupCornerRadius, style: .continuous))
        }
    }

    private func row(icon: String,
                     title: LocalizedStringKey?,
                     verbatimTitle: String? = nil,
                     subtitle: LocalizedStringKey?,
                     dimmed: Bool = false,
                     @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: Metrics.iconGap) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(dimmed ? Metrics.secondaryText : .white)
                .frame(width: Metrics.iconWidth)
            VStack(alignment: .leading, spacing: 5) {
                if let title {
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundStyle(dimmed ? Metrics.secondaryText : .white)
                } else if let verbatimTitle {
                    Text(verbatim: verbatimTitle)
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(Metrics.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, Metrics.rowInset)
        .padding(.vertical, 18)
    }

    private func infoRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Metrics.iconGap) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(.white)
                .frame(width: Metrics.iconWidth)
            Text(text)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.rowInset)
        .padding(.vertical, 18)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 0.5)
            .padding(.leading, Metrics.separatorInset)
    }

    private func segmented<Value: Equatable>(options: [(Text, Value)],
                                             selection: Binding<Value>) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                        selection.wrappedValue = option.1
                    }
                } label: {
                    option.0
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if selection.wrappedValue == option.1 {
                                Capsule().fill(Color(white: 0.42))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color(white: 0.22)))
    }
}
