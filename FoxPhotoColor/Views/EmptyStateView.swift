import SwiftUI
import PhotosUI

/// First-run screen mirroring the reference: a five-page onboarding carousel,
/// one page per capability (serif headline + quiet subtitle + page dots),
/// with the logo and the big + picker fixed above/below the swipeable text.
struct EmptyStateView: View {
    @Binding var pickerItem: PhotosPickerItem?
    @State private var page = 0
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 30
    @ScaledMetric(relativeTo: .subheadline) private var subtitleSize: CGFloat = 14

    /// The onboarding green, washed like the card canvas (measured off the
    /// reference empty screen).
    static let backgroundGradient = CanvasBackground(color: RGBAColor(r: 0.45, g: 0.58, b: 0.43))

    /// The five capabilities, straight from the reference carousel.
    private static let pages: [(title: LocalizedStringKey, subtitle: LocalizedStringKey)] = [
        ("onboard.moment.title", "onboard.moment.subtitle"),
        ("onboard.palette.title", "onboard.palette.subtitle"),
        ("onboard.journal.title", "onboard.journal.subtitle"),
        ("onboard.stamp.title", "onboard.stamp.subtitle"),
        ("onboard.wallpaper.title", "onboard.wallpaper.subtitle"),
    ]

    var body: some View {
        ZStack {
            Self.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                LayeredFoxMark()
                    .frame(width: 84, height: 96)
                    .padding(.bottom, 30)

                // Swipeable feature blurbs. Fixed height so the logo, dots and
                // + button never shift as titles wrap differently.
                TabView(selection: $page) {
                    ForEach(Array(Self.pages.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 14) {
                            Text(item.title)
                                .font(.system(size: titleSize, weight: .bold, design: .serif))
                                .tracking(-0.5)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                            Text(item.subtitle)
                                .font(.system(size: subtitleSize, design: .serif))
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 44)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 130)

                // Page dots (reference style: small, current one solid white).
                HStack(spacing: 9) {
                    ForEach(0..<Self.pages.count, id: \.self) { index in
                        Circle()
                            .fill(.white.opacity(index == page ? 1 : 0.35))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.top, 8)
                .animation(.spring(response: 0.3, dampingFraction: 1.0), value: page)

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        GlassCircle()
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .frame(width: 108, height: 108)
                    // Reference: the + slowly breathes while waiting.
                    .modifier(BreathingScale())
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 40)

                Spacer()
                Spacer()
            }
        }
    }
}

/// Minimal geometric fox head, drawn in code so it scales and recolors freely.
/// Kin to the codefox fox: tall ears, soft jaw, cream muzzle.
struct FoxMark: View {
    var body: some View {
        FoxSilhouette()
            .fill(Color(red: 0.89, green: 0.36, blue: 0.16))
            .aspectRatio(1.05, contentMode: .fit)
    }
}

/// Detail-free angular fox head (the simple badge glyph: two ears with a
/// notch between, cheeks tapering to a pointed chin), usable as a tinted
/// shadow layer.
struct FoxSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + w * x, y: rect.minY + h * y)
        }
        var p = Path()
        p.move(to: pt(0.04, 0.02))   // left ear tip
        p.addLine(to: pt(0.32, 0.24)) // inner slope of left ear
        p.addLine(to: pt(0.50, 0.16)) // notch between the ears
        p.addLine(to: pt(0.68, 0.24)) // inner slope of right ear
        p.addLine(to: pt(0.96, 0.02)) // right ear tip
        p.addLine(to: pt(1.00, 0.42)) // right cheek
        p.addLine(to: pt(0.50, 1.00)) // chin point
        p.addLine(to: pt(0.00, 0.42)) // left cheek
        p.closeSubpath()
        return p
    }
}

/// The onboarding logo: three detail-free fox silhouettes stacked like the
/// reference's three ellipses (pale above, deep below). On appear the stack
/// floats up from below as one, then the layers fan apart vertically.
struct LayeredFoxMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = stacked & offscreen-ish, 1 = risen & fanned.
    @State private var fan: CGFloat = 0
    @State private var risen = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let spread = geo.size.height * 0.14
            ZStack {
                FoxSilhouette()
                    .fill(Color(red: 0.85, green: 0.89, blue: 0.66).opacity(0.95))
                    .frame(width: w, height: w * 0.9)
                    .offset(y: -spread * fan)
                FoxSilhouette()
                    .fill(Color(red: 0.36, green: 0.46, blue: 0.30))
                    .frame(width: w, height: w * 0.9)
                FoxSilhouette()
                    .fill(Color(red: 0.15, green: 0.22, blue: 0.16).opacity(0.92))
                    .frame(width: w, height: w * 0.9)
                    .offset(y: spread * fan)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .offset(y: risen ? 0 : geo.size.height * 0.5)
            .opacity(risen ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { risen = true; fan = 1; return }
            // Rise as one stack, then fan the layers apart.
            withAnimation(.spring(response: 0.55, dampingFraction: 1.0)) {
                risen = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 1.0).delay(0.45)) {
                fan = 1
            }
        }
    }
}

/// Slow idle breathing (reference: the big + gently scales in and out).
struct BreathingScale: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inhale = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(inhale ? 1.05 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    inhale = true
                }
            }
    }
}

/// Apple-glass circular button chrome, like the reference app's buttons: a
/// material blur with a light-from-above rim (bright top edge fading out) and
/// a faint inner sheen.
struct GlassCircle: View {
    var isDark = false

    var body: some View {
        let rim = isDark ? Color.black : Color.white
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                // Sheen: subtle wash that reads as light hitting the glass.
                Circle().fill(
                    LinearGradient(colors: [rim.opacity(0.16), rim.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                // Rim: brighter along the top edge, nearly gone at the bottom.
                Circle().strokeBorder(
                    LinearGradient(colors: [rim.opacity(0.55), rim.opacity(0.08)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            )
    }
}

/// Instant press feedback per the apple-design skill: respond on touch-down,
/// critically damped spring, no lockout. Reduced motion swaps scale for opacity.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1.0)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1.0)
            .animation(reduceMotion ? .easeInOut(duration: 0.15)
                                    : .spring(response: 0.25, dampingFraction: 1.0),
                       value: configuration.isPressed)
    }
}
