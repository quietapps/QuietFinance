import SwiftUI
import Combine

/// App-wide transient feedback for failures and confirmations that previously
/// went unreported (backup write failures, save rollbacks, denied permissions).
/// Singleton so non-view call sites (services, schedulers) can post too.
/// objectWillChange is declared manually (same as UndoStash): the project's
/// MainActor default isolation makes synthesized @Published conformance fail.
final class ToastCenter: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()

    static let shared = ToastCenter()

    enum Style { case error, warning, success }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let style: Style
        let detail: String?
    }

    private(set) var current: Toast? {
        willSet { objectWillChange.send() }
    }

    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, style: Style = .error, detail: String? = nil) {
        current = Toast(message: message, style: style, detail: detail)
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
    }
}
