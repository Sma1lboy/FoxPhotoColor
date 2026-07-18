import SwiftUI
import PhotosUI

/// First-run screen: green gradient, logo mark, serif headline, big + picker —
/// mirrors the reference onboarding card.
struct EmptyStateView: View {
    @Binding var pickerItem: PhotosPickerItem?
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 30
    @ScaledMetric(relativeTo: .subheadline) private var subtitleSize: CGFloat = 14

    /// The onboarding green, washed like the card canvas (measured off the
    /// reference empty screen).
    static let backgroundGradient = CanvasBackground(color: RGBAColor(r: 0.45, g: 0.58, b: 0.43))

    var body: some View {
        ZStack {
            Self.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                logoMark
                    .padding(.bottom, 36)

                Text("empty.title")
                    .font(.system(size: titleSize, weight: .bold, design: .serif))
                    .tracking(-0.5) // large display text wants negative tracking (skill §15)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 44)

                Text("empty.subtitle")
                    .font(.system(size: subtitleSize))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.horizontal, 44)

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        GlassCircle()
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .frame(width: 108, height: 108)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 48)

                Spacer()
                Spacer()
            }
        }
    }

    /// The app's logo mark: a minimal geometric fox head (kin to the codefox
    /// fox) — two ears and a muzzle cut from a rounded face, in the brand's
    /// warm orange over a soft cream chest.
    private var logoMark: some View {
        FoxMark()
            .frame(width: 76, height: 68)
    }
}

/// Minimal geometric fox head, drawn in code so it scales and recolors freely.
/// Kin to the codefox fox: tall ears, soft jaw, cream muzzle.
struct FoxMark: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Ears + head silhouette in the brand orange.
                Path { p in
                    // Left ear
                    p.move(to: CGPoint(x: w * 0.08, y: h * 0.02))
                    p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.30))
                    p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.42))
                    p.closeSubpath()
                    // Right ear
                    p.move(to: CGPoint(x: w * 0.92, y: h * 0.02))
                    p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.30))
                    p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.42))
                    p.closeSubpath()
                }
                .fill(Color(red: 0.89, green: 0.36, blue: 0.16))

                // Face: rounded wedge tapering to the muzzle.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.06, y: h * 0.30))
                    p.addQuadCurve(to: CGPoint(x: w * 0.94, y: h * 0.30),
                                   control: CGPoint(x: w * 0.5, y: h * 0.14))
                    p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.98),
                                   control: CGPoint(x: w * 0.96, y: h * 0.78))
                    p.addQuadCurve(to: CGPoint(x: w * 0.06, y: h * 0.30),
                                   control: CGPoint(x: w * 0.04, y: h * 0.78))
                    p.closeSubpath()
                }
                .fill(Color(red: 0.89, green: 0.36, blue: 0.16))

                // Cream muzzle: soft triangle at the chin.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.30, y: h * 0.62))
                    p.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.62),
                                   control: CGPoint(x: w * 0.5, y: h * 0.52))
                    p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.98),
                                   control: CGPoint(x: w * 0.72, y: h * 0.88))
                    p.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.62),
                                   control: CGPoint(x: w * 0.28, y: h * 0.88))
                    p.closeSubpath()
                }
                .fill(Color(red: 0.98, green: 0.94, blue: 0.86))

                // Eyes: two dark dots.
                Circle()
                    .fill(Color(red: 0.13, green: 0.12, blue: 0.18))
                    .frame(width: w * 0.075, height: w * 0.075)
                    .position(x: w * 0.32, y: h * 0.50)
                Circle()
                    .fill(Color(red: 0.13, green: 0.12, blue: 0.18))
                    .frame(width: w * 0.075, height: w * 0.075)
                    .position(x: w * 0.68, y: h * 0.50)
                // Nose.
                Circle()
                    .fill(Color(red: 0.13, green: 0.12, blue: 0.18))
                    .frame(width: w * 0.09, height: w * 0.09)
                    .position(x: w * 0.5, y: h * 0.80)
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
