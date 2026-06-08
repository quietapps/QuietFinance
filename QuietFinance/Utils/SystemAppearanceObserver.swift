import SwiftUI
import AppKit
import Combine

/// Publishes the OS-level light/dark setting and updates when the user changes
/// it in System Settings. Used so the app's "System" theme can be fed to
/// `.preferredColorScheme` as a CONCRETE scheme rather than `nil`.
///
/// Why concrete: `preferredColorScheme(nil)` releases the override but does not
/// re-resolve the app's dynamic color tokens in the same render pass, so
/// selecting "System" appeared to need a second click to take effect. Passing a
/// concrete `.light`/`.dark` (kept in sync here) makes the switch land on the
/// first click while still tracking the OS.
final class SystemAppearanceObserver: ObservableObject {
    @Published var scheme: ColorScheme

    private var token: NSObjectProtocol?

    init() {
        scheme = Self.current()
        // Fires when the user flips Light/Dark (or Auto crosses) in System Settings.
        token = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheme = Self.current()
        }
    }

    deinit {
        if let token { DistributedNotificationCenter.default().removeObserver(token) }
    }

    /// Reads the current OS appearance. `AppleInterfaceStyle` is absent in Light
    /// and equals "Dark" in Dark; it lives in the global domain and is readable
    /// from `UserDefaults.standard` even in a sandboxed app.
    static func current() -> ColorScheme {
        let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? ""
        return style.lowercased().contains("dark") ? .dark : .light
    }
}
