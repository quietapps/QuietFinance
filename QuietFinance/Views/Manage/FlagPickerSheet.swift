import SwiftUI

struct FlagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var flag: String
    @Binding var code: String
    @State private var query: String = ""

    private struct Entry: Identifiable, Hashable {
        let id: String  // ISO code
        let name: String
        let emoji: String
    }

    private static let entries: [Entry] = {
        let regions = Locale.Region.isoRegions.filter { $0.identifier.count == 2 }
        let locale = Locale(identifier: "en_US")
        return regions.compactMap { r -> Entry? in
            let id = r.identifier
            guard let name = locale.localizedString(forRegionCode: id) else { return nil }
            let emoji = flagFromCode(id)
            guard !emoji.isEmpty else { return nil }
            return Entry(id: id, name: name, emoji: emoji)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    private var filtered: [Entry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Self.entries }
        return Self.entries.filter {
            $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pick country flag").font(Typo.serifNum(20))
                Spacer()
                GhostButton(action: { dismiss() }) { Text("Close") }
            }
            .padding(16)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11)).foregroundStyle(Color.lInk3)
                TextField("Search by country or ISO code", text: $query)
                    .textFieldStyle(.plain)
                    .font(Typo.sans(13))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.lSunken.opacity(0.6))
            .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
            .clipShape(Capsule())
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider().overlay(Color.lLine)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 4)], spacing: 4) {
                    ForEach(filtered) { e in
                        Button {
                            flag = e.emoji
                            if code.trimmingCharacters(in: .whitespaces).isEmpty {
                                code = e.id
                            }
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Text(e.emoji).font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(e.name).font(Typo.sans(13, weight: .medium))
                                        .foregroundStyle(Color.lInk).lineLimit(1)
                                    Text(e.id).font(Typo.mono(10))
                                        .foregroundStyle(Color.lInk3)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .background(Color.lSunken.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(Color.lBg)
        .overlay(alignment: .topLeading) {
            Button("") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .hidden()
                .frame(width: 0, height: 0)
        }
    }

    private static func flagFromCode(_ raw: String) -> String {
        let upper = raw.uppercased()
        guard upper.count == 2 else { return "" }
        let base: UInt32 = 127397
        var result = ""
        for char in upper.unicodeScalars {
            guard char.value >= 65, char.value <= 90 else { return "" }
            guard let scalar = UnicodeScalar(base + char.value) else { return "" }
            result.append(Character(scalar))
        }
        return result
    }
}
