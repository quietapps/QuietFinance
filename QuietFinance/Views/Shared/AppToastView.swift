import SwiftUI

/// Bottom-anchored transient toast driven by `ToastCenter`. Visual language
/// matches `UndoToast` so the two can stack in the same overlay.
struct AppToastView: View {
    @EnvironmentObject var toasts: ToastCenter

    var body: some View {
        Group {
            if let toast = toasts.current {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon(for: toast.style))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(iconColor(for: toast.style))
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.message)
                            .font(Typo.sans(12, weight: .medium))
                            .foregroundStyle(Color.lInk)
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail = toast.detail {
                            Text(detail)
                                .font(Typo.sans(11))
                                .foregroundStyle(Color.lInk3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    Button {
                        toasts.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.lInk3)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .accessibilityLabel("Dismiss notification")
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(background(for: toast.style))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(border(for: toast.style), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                .frame(maxWidth: 480)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(toast.message)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toasts.current)
    }

    private func icon(for style: ToastCenter.Style) -> String {
        switch style {
        case .error:   return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    private func iconColor(for style: ToastCenter.Style) -> Color {
        switch style {
        case .error:   return .lLoss
        case .warning: return .lInk2
        case .success: return .lGain
        }
    }

    private func background(for style: ToastCenter.Style) -> Color {
        switch style {
        case .error: return Color.lLossSoft.opacity(0.4)
        case .warning, .success: return Color.lPanel
        }
    }

    private func border(for style: ToastCenter.Style) -> Color {
        switch style {
        case .error: return Color.lLoss.opacity(0.4)
        case .warning, .success: return Color.lLine
        }
    }
}
