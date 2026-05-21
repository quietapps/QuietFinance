import SwiftUI
import SwiftData

struct GlobalSearchField: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Account.name)  private var accounts: [Account]
    @Query(sort: \Person.name)   private var people: [Person]
    @Query(sort: \Country.name)  private var countries: [Country]
    @Query(sort: \AssetType.name) private var assetTypes: [AssetType]

    @State private var query: String = ""
    @FocusState private var focused: Bool
    @State private var showResults: Bool = false

    enum Kind { case account, person, country, assetType }

    struct Result: Identifiable {
        let id = UUID()
        let kind: Kind
        let entityID: UUID
        let label: String
        let detail: String
        let screen: Screen
        let color: Color
    }

    private var results: [Result] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var out: [Result] = []
        for a in accounts {
            let nameHit = a.name.lowercased().contains(q)
            let instHit = a.institution.lowercased().contains(q)
            let notesHit = a.notes.lowercased().contains(q)
            guard nameHit || instHit || notesHit else { continue }
            var details = [a.person?.name, a.assetType?.name, a.country?.name].compactMap { $0 }
            if instHit && !a.institution.isEmpty { details.append("📍 \(a.institution)") }
            if notesHit && !a.notes.isEmpty {
                let snippet = a.notes.count > 50 ? String(a.notes.prefix(50)) + "…" : a.notes
                details.append("📝 \(snippet)")
            }
            let detail = details.joined(separator: " · ")
            let col = a.assetType.map { Palette.color(for: $0.category) } ?? .lInk3
            out.append(Result(kind: .account, entityID: a.id, label: a.name, detail: detail,
                              screen: .accounts, color: col))
        }
        for p in people where p.name.lowercased().contains(q) {
            let col = Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name)
            out.append(Result(kind: .person, entityID: p.id, label: p.name,
                              detail: "Person · \(p.accounts.count) accounts",
                              screen: .people, color: col))
        }
        for c in countries where c.name.lowercased().contains(q) || c.code.lowercased().contains(q) {
            let col = Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code)
            out.append(Result(kind: .country, entityID: c.id, label: "\(c.flag) \(c.name)",
                              detail: "Country · \(c.code)",
                              screen: .countries, color: col))
        }
        for t in assetTypes where t.name.lowercased().contains(q) {
            out.append(Result(kind: .assetType, entityID: t.id, label: t.name,
                              detail: "Asset type · \(t.category.rawValue)",
                              screen: .assetTypes, color: Palette.color(for: t.category)))
        }
        return Array(out.prefix(24))
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.lInk3)
            TextField("Search accounts, institution, notes, people, countries, types", text: $query)
                .textFieldStyle(.plain)
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk)
                .focused($focused)
                .frame(minWidth: 120, maxWidth: 340)
                .onSubmit {
                    if let first = results.first { open(first) }
                }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.lInk3)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            } else {
                Text("⌘F")
                    .font(Typo.mono(9, weight: .medium))
                    .foregroundStyle(Color.lInk3)
                    .padding(.horizontal, 4)
                    .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.lSunken.opacity(0.6))
        .overlay(Capsule().stroke(focused ? Color.lInk.opacity(0.35) : Color.lLine, lineWidth: 1))
        .clipShape(Capsule())
        .onChange(of: app.globalSearchFocusTick) { _, _ in focused = true }
        .onChange(of: focused) { _, newVal in showResults = newVal && !query.isEmpty }
        .onChange(of: query) { _, newVal in showResults = focused && !newVal.isEmpty }
        .overlay(alignment: .topLeading) {
            if showResults {
                resultsList
                    .frame(width: 520)
                    .background(Color.lPanel)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lLine, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
                    .offset(y: 36)
                    .zIndex(999)
            }
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        let r = results
        VStack(alignment: .leading, spacing: 0) {
            if r.isEmpty {
                Text("No matches.")
                    .font(Typo.serifItalic(13))
                    .foregroundStyle(Color.lInk3)
                    .padding(16)
            } else {
                HStack {
                    Text("\(r.count) result\(r.count == 1 ? "" : "s")")
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                    Spacer()
                    Text("↩ open · esc close")
                        .font(Typo.mono(10))
                        .foregroundStyle(Color.lInk4)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.lSunken.opacity(0.5))
                Divider().overlay(Color.lLine)
                VStack(spacing: 0) {
                    ForEach(Array(r.enumerated()), id: \.element.id) { idx, res in
                        Button { open(res) } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(res.color)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(res.label)
                                        .font(Typo.sans(14, weight: .semibold))
                                        .foregroundStyle(Color.lInk)
                                        .lineLimit(1)
                                    Text(res.detail)
                                        .font(Typo.sans(12))
                                        .foregroundStyle(Color.lInk3)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Text(kindBadge(res.kind))
                                    .font(Typo.eyebrow).tracking(1.2)
                                    .foregroundStyle(Color.lInk3)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        if idx < r.count - 1 {
                            Divider().overlay(Color.lLine)
                        }
                    }
                }
            }
        }
        .background(Color.lPanel)
    }

    private func kindBadge(_ k: Kind) -> String {
        switch k {
        case .account:   return "ACCT"
        case .person:    return "PERSON"
        case .country:   return "COUNTRY"
        case .assetType: return "TYPE"
        }
    }

    private func open(_ r: Result) {
        app.selectedScreen = r.screen
        switch r.kind {
        case .account:   app.pendingFocusAccountID   = r.entityID
        case .person:    app.pendingFocusPersonID    = r.entityID
        case .country:   app.pendingFocusCountryID   = r.entityID
        case .assetType: app.pendingFocusAssetTypeID = r.entityID
        }
        query = ""
        showResults = false
        focused = false
    }
}
