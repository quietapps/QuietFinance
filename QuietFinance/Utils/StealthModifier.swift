import SwiftUI

/// Blurs currency / number values when `AppState.stealthMode` is on.
/// Reveals on hover. Apply via `.stealthAmount()` on any Text or HStack
/// that contains a sensitive amount.
struct StealthAmount: ViewModifier {
    @EnvironmentObject var app: AppState
    @State private var hovering = false

    func body(content: Content) -> some View {
        let active = app.stealthMode && !hovering
        content
            .blur(radius: active ? 7 : 0)
            .opacity(active ? 0.85 : 1)
            .onHover { hovering = $0 }
            .animation(.easeInOut(duration: 0.14), value: active)
    }
}

extension View {
    /// Marks a view as a sensitive amount — blurs in stealth mode, reveals on hover.
    func stealthAmount() -> some View { modifier(StealthAmount()) }
}

/// Conditional wrapper — applies StealthAmount only when `blur` is true.
struct StealthIfNeeded: ViewModifier {
    let blur: Bool
    func body(content: Content) -> some View {
        if blur { content.stealthAmount() } else { content }
    }
}
