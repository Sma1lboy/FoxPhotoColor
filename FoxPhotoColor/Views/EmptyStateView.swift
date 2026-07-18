import SwiftUI
import PhotosUI

/// First-run screen: green gradient, logo mark, serif headline, big + picker —
/// mirrors the reference onboarding card.
struct EmptyStateView: View {
    @Binding var pickerItem: PhotosPickerItem?
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 30
    @ScaledMetric(relativeTo: .subheadline) private var subtitleSize: CGFloat = 14

    static let backgroundTop = Color(red: 0.58, green: 0.67, blue: 0.45)
    static let backgroundBottom = Color(red: 0.42, green: 0.53, blue: 0.33)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.backgroundTop, Self.backgroundBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                logoMark
                    .padding(.bottom, 36)

                Text("empty.title")
                    .font(.system(size: titleSize, weight: .bold, design: .serif))
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
                    .frame(width: 92, height: 92)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 56)

                Spacer()
                Spacer()
            }
        }
    }

    /// Stacked soft ellipses — the app's logo mark (light → mid → deep green).
    private var logoMark: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.16, green: 0.22, blue: 0.11))
                .frame(width: 46, height: 54)
                .offset(y: 10)
            Ellipse()
                .fill(Color(red: 0.45, green: 0.56, blue: 0.30))
                .frame(width: 46, height: 54)
                .offset(y: 0)
            Ellipse()
                .fill(Color(red: 0.85, green: 0.90, blue: 0.68))
                .frame(width: 46, height: 54)
                .offset(y: -10)
                .opacity(0.92)
        }
        .frame(width: 64, height: 78)
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
