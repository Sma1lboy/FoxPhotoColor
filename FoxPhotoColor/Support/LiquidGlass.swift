import SwiftUI

// iOS 26 Liquid Glass adoption with two safety nets:
// - `#if compiler(>=6.2)` keeps the file compiling under the Xcode 16.2
//   simulator harness (no glassEffect symbol there);
// - `#available(iOS 26.0, *)` falls back to the existing material look on
//   older systems at runtime.

extension View {
    /// Liquid Glass anchored in `shape`, or ultra-thin material below iOS 26.
    @ViewBuilder
    func fpcGlass(in shape: some Shape, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: AnyShape(shape))
        }
        #else
        background(.ultraThinMaterial, in: AnyShape(shape))
        #endif
    }
}

/// The top bar's circular chrome buttons: real Liquid Glass on iOS 26,
/// the hand-rolled GlassCircle (material + top-lit rim) elsewhere.
struct LiquidGlassCircle: ViewModifier {
    let isDark: Bool

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content.background(GlassCircle(isDark: isDark))
        }
        #else
        content.background(GlassCircle(isDark: isDark))
        #endif
    }
}
