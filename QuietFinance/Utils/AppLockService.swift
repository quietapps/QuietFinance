import Foundation
import Combine
import LocalAuthentication
import AppKit

/// Local-only app lock. Uses LocalAuthentication (Touch ID, Apple Watch,
/// or system password) to gate the UI on launch. No data is encrypted —
/// the SwiftData store remains the same plaintext sqlite. This is a
/// shoulder-surf protection, not a cryptographic safe.
@MainActor
final class AppLockGate: ObservableObject {
    @Published var isLocked: Bool

    private var idleTimer: Timer?
    private var eventMonitor: Any?
    private var lastActivity: Date = .now

    init(initiallyLocked: Bool) {
        self.isLocked = initiallyLocked
    }

    deinit {
        if let m = eventMonitor { NSEvent.removeMonitor(m) }
        idleTimer?.invalidate()
    }

    /// Returns true when the device can prompt for authentication.
    static var available: Bool {
        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)
    }

    /// Prompts for Touch ID / password. On success unlocks the gate. On
    /// failure leaves it locked; caller can retry. If the device cannot
    /// evaluate any policy (e.g. no Touch ID, no password set on a Mac
    /// signed in via auto-login), the gate fails open to avoid lockout.
    func authenticate(reason: String) async {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            // No auth method available — don't lock the user out of their data.
            isLocked = false
            startIdleMonitorIfConfigured()
            return
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                                  localizedReason: reason)
            if ok {
                isLocked = false
                startIdleMonitorIfConfigured()
            }
        } catch {
            // Stay locked. User can retry via the Unlock button.
        }
    }

    // MARK: - Idle auto-lock

    /// Reads `autoLockIdleMinutes` from defaults and (re)starts the idle
    /// monitor. Call after unlock and whenever the setting changes. A value
    /// of 0 disables auto-lock and stops the monitor.
    func startIdleMonitorIfConfigured() {
        stopIdleMonitor()
        let minutes = UserDefaults.standard.integer(forKey: "autoLockIdleMinutes")
        guard minutes > 0,
              UserDefaults.standard.object(forKey: "requireAppLock") as? Bool ?? true,
              !isLocked else { return }
        lastActivity = .now
        installEventMonitor()
        scheduleTimer(minutes: minutes)
    }

    func stopIdleMonitor() {
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
        idleTimer?.invalidate()
        idleTimer = nil
    }

    /// Force a re-read of the setting; used by Settings UI when the user
    /// changes the idle minutes or toggles app lock.
    func reapplyIdleSetting() {
        if isLocked {
            stopIdleMonitor()
        } else {
            startIdleMonitorIfConfigured()
        }
    }

    private func installEventMonitor() {
        let mask: NSEvent.EventTypeMask = [
            .keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown,
            .otherMouseDown, .scrollWheel, .flagsChanged
        ]
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.lastActivity = .now
            return event
        }
    }

    private func scheduleTimer(minutes: Int) {
        let interval: TimeInterval = 15
        let threshold = TimeInterval(minutes * 60)
        idleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isLocked { self.stopIdleMonitor(); return }
                if Date().timeIntervalSince(self.lastActivity) >= threshold {
                    self.isLocked = true
                    self.stopIdleMonitor()
                }
            }
        }
    }
}
