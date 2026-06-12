import AppKit
import SwiftUI

enum Clipboard {
    static func copy(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }
}

/// Right-click copy menu for numeric cells and table rows. Suppressed in
/// stealth mode — blurred values must not be exfiltrated via the clipboard.
struct CopyableModifier: ViewModifier {
    @Environment(\.stealthMode) private var stealth
    let value: String
    let row: String?

    func body(content: Content) -> some View {
        if stealth {
            content
        } else {
            content.contextMenu {
                Button("Copy value") { Clipboard.copy(value) }
                if let row {
                    Button("Copy row as CSV") { Clipboard.copy(row) }
                }
            }
        }
    }
}

extension View {
    func copyable(value: String, row: String? = nil) -> some View {
        modifier(CopyableModifier(value: value, row: row))
    }
}
