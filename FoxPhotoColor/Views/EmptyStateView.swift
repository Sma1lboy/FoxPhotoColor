import SwiftUI
import PhotosUI

/// First-run screen: green gradient, logo mark, serif headline, big + picker —
/// mirrors the reference onboarding card.
struct EmptyStateView: View {
    @Binding var pickerItem: PhotosPickerItem?

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
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 44)

                Text("empty.subtitle")
                    .font(.system(size: 14))
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

    /// Two stacked soft ellipses — the app's logo mark.
    private var logoMark: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.18, green: 0.25, blue: 0.13).opacity(0.9))
                .frame(width: 54, height: 62)
                .offset(y: 8)
            Ellipse()
                .fill(Color(red: 0.87, green: 0.92, blue: 0.72))
                .frame(width: 44, height: 50)
                .offset(y: -8)
                .blendMode(.softLight)
            Ellipse()
                .fill(Color(red: 0.55, green: 0.66, blue: 0.38))
                .frame(width: 44, height: 50)
                .offset(y: -2)
                .opacity(0.85)
        }
        .frame(width: 64, height: 76)
    }
}

/// Instant press feedback per the apple-design skill: respond on touch-down,
/// critically damped spring, no lockout.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 1.0), value: configuration.isPressed)
    }
}
