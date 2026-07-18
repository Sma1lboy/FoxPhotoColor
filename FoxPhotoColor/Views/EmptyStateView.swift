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
                        Circle()
                            .fill(Color.white.opacity(0.14))
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

    /// Stacked soft ellipses — the app's logo mark: a pale leaf behind, a deep
    /// green one in front, offset down (matching the reference mark).
    private var logoMark: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.85, green: 0.89, blue: 0.70))
                .frame(width: 52, height: 66)
                .offset(y: -12)
            Ellipse()
                .fill(Color(red: 0.24, green: 0.32, blue: 0.20))
                .frame(width: 52, height: 66)
                .offset(y: 12)
                .opacity(0.9)
        }
        .frame(width: 64, height: 96)
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
