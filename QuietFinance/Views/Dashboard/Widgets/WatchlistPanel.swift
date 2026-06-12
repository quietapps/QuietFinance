import SwiftUI

/// Pinned accounts with current value and QoQ delta; tap to jump to the
/// account in Manage.
struct WatchlistPanel: View {
    @EnvironmentObject var app: AppState
    let accounts: [Account]
    let activeSnap: Snapshot?
    let prevSnap: Snapshot?

    var body: some View {
        let target = app.displayCurrency
        let pinned = app.pinnedAccountIDs
        let byID = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let rows: [Account] = pinned.compactMap { byID[$0] }
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("WATCHLIST")
                            .font(Typo.eyebrow).tracking(1.5)
                            .foregroundStyle(Color.lInk3)
                        Text("Pinned accounts")
                            .font(Typo.serifNum(18))
                            .foregroundStyle(Color.lInk)
                    }
                    Spacer()
                    Text("\(rows.count) pinned")
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, a in
                    watchlistRow(a, target: target)
                    if idx < rows.count - 1 {
                        Divider().overlay(Color.lLine)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func watchlistRow(_ a: Account, target: Currency) -> some View {
        let curNative = activeSnap?.values.first { $0.account?.id == a.id }?.nativeValue
        let prevNative = prevSnap?.values.first { $0.account?.id == a.id }?.nativeValue
        let curDisplay: Double? = {
            guard let v = curNative, let s = activeSnap else { return nil }
            return CurrencyConverter.convert(nativeValue: v, from: a.nativeCurrency, to: target, in: s)
        }()
        let prevDisplay: Double? = {
            guard let v = prevNative, let s = prevSnap else { return nil }
            return CurrencyConverter.convert(nativeValue: v, from: a.nativeCurrency, to: target, in: s)
        }()
        let diff: Double? = {
            guard let c = curDisplay, let p = prevDisplay else { return nil }
            return c - p
        }()
        Button {
            app.pendingFocusAccountID = a.id
            app.selectedScreen = .accounts
            app.touchRecent(.account, id: a.id, label: a.name)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.name)
                        .font(Typo.sans(13, weight: .medium))
                        .foregroundStyle(Color.lInk)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let p = a.person?.name { Text(p) }
                        if let cn = a.country?.code { Text(cn) }
                        if let t = a.assetType?.name { Text(t) }
                    }
                    .font(Typo.sans(11))
                    .foregroundStyle(Color.lInk3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(curDisplay.map { Fmt.currency($0, target) } ?? "—")
                        .font(Typo.mono(13, weight: .semibold))
                        .foregroundStyle(Color.lInk)
                    if let d = diff {
                        Text(Fmt.signedDelta(d, target))
                            .font(Typo.mono(11))
                            .foregroundStyle(Palette.deltaColor(d))
                    } else {
                        Text("—")
                            .font(Typo.mono(11))
                            .foregroundStyle(Color.lInk4)
                    }
                }
                Button {
                    app.togglePinnedAccount(a.id)
                } label: {
                    Image(systemName: "star.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.lInk3)
                        .padding(.leading, 8)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .help("Unpin from watchlist")
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}
