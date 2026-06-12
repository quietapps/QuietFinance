import SwiftUI
import SwiftData

/// What-if scenario screen: fork a snapshot into an in-memory sandbox, tweak
/// values, add hypothetical items, and compare against the baseline. Nothing
/// here is persisted, exported, or backed up — by construction.
struct ScenarioView: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

    var body: some View {
        if let session = app.scenarioSession {
            ScenarioEditor(session: session)
        } else if snapshots.isEmpty {
            EditorialEmpty(
                eyebrow: "Scenario · What-if",
                title: "A hypothesis",
                titleItalic: "needs a baseline.",
                body: "Scenarios fork a snapshot so you can ask what-if without touching real data. Capture a snapshot first, then return here.",
                detail: "Nothing in a scenario is ever saved.",
                ctaLabel: "Create first snapshot",
                cta: {
                    app.newSnapshotRequested = true
                    app.selectedScreen = .snapshots
                },
                illustration: "wand.and.stars"
            )
        } else {
            EditorialEmpty(
                eyebrow: "Scenario · What-if",
                title: "A hypothesis,",
                titleItalic: "not yet posed.",
                body: "Fork the latest snapshot into a sandbox: sell the house, pay off the loan, double the crypto — and see what happens to net worth, allocation, and your goal ETA.",
                detail: "Scenarios live in memory only. Quit the app and they're gone; your real ledger is never touched.",
                ctaLabel: "Fork latest snapshot",
                cta: {
                    if let latest = snapshots.first {
                        app.scenarioSession = ScenarioSession(forkOf: latest)
                    }
                },
                illustration: "wand.and.stars"
            )
        }
    }
}

private struct ScenarioEditor: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var session: ScenarioSession
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

    @State private var newName: String = ""
    @State private var newCategory: AssetCategory = .cash
    @State private var newCurrency: Currency = .USD
    @State private var newValue: Double = 0
    @State private var confirmingDiscard = false

    private var ccy: Currency { app.displayCurrency }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            kpiRow
            allocationPanel
            Panel { table }
            addHypotheticalPanel
        }
        .confirmationDialog("Discard this scenario?",
                            isPresented: $confirmingDiscard,
                            titleVisibility: .visible) {
            Button("Discard", role: .destructive) { app.scenarioSession = nil }
                .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The sandbox is in memory only — discarding loses every tweak. Your real data was never touched.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCENARIO · WHAT-IF")
                        .font(Typo.eyebrow).tracking(1.5)
                        .foregroundStyle(Color.lInk3)
                    HStack(spacing: 8) {
                        Text("Scenario").font(Typo.serifNum(32))
                        Text("— forked from \(session.baselineLabel)")
                            .font(Typo.serifItalic(28))
                            .foregroundStyle(Color.lInk3)
                    }
                    .foregroundStyle(Color.lInk)
                }
                Spacer()
                Pill(text: "Hypothetical — not saved", emphasis: true)
                GhostButton(action: { session.resetAll() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 10, weight: .semibold))
                        Text("Reset values")
                    }
                }
                .disabled(!session.hasChanges)
                GhostButton(action: { confirmingDiscard = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash").font(.system(size: 10, weight: .semibold))
                        Text("Discard")
                    }
                }
            }
        }
    }

    private var kpiRow: some View {
        let baseline = session.baselineTotal(in: ccy)
        let scenario = session.scenarioTotal(in: ccy)
        let delta = scenario - baseline
        let pct = baseline != 0 ? delta / abs(baseline) * 100 : 0
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
            KPICard(label: "Baseline",
                    value: Fmt.compact(baseline, ccy),
                    sub: session.baselineLabel,
                    deltaText: nil, deltaUp: true)
            KPICard(label: "Scenario",
                    value: Fmt.compact(scenario, ccy),
                    sub: "with your tweaks",
                    deltaText: nil, deltaUp: true)
            KPICard(label: "Δ Net worth",
                    value: "\(delta >= 0 ? "+" : "−")\(Fmt.compact(abs(delta), ccy))",
                    sub: String(format: "%+.1f%%", pct),
                    valueColor: delta >= 0 ? .lGain : .lLoss,
                    deltaText: nil, deltaUp: delta >= 0)
            goalEtaCard
        }
    }

    @ViewBuilder
    private var goalEtaCard: some View {
        if let goal = goalDisplay(), goal > 0 {
            let history = historyForFit()
            let before = session.goalETA(history: history, method: app.forecastMethod,
                                         goal: goal, in: ccy, scenario: false)
            let after = session.goalETA(history: history, method: app.forecastMethod,
                                        goal: goal, in: ccy, scenario: true)
            KPICard(label: "Goal ETA",
                    value: after.map(formatDateLabel) ?? "—",
                    sub: etaDeltaText(before: before, after: after),
                    deltaText: nil, deltaUp: true)
        } else {
            KPICard(label: "Goal ETA",
                    value: "—",
                    sub: "Set a goal in Settings",
                    deltaText: nil, deltaUp: true)
        }
    }

    private var allocationPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "Allocation shift", meta: "gross magnitude by category")
                VStack(alignment: .leading, spacing: 14) {
                    allocationBar(label: "BASELINE", items: session.allocation(scenario: false, in: ccy))
                    allocationBar(label: "SCENARIO", items: session.allocation(scenario: true, in: ccy))
                }
                .padding(18)
            }
        }
    }

    @ViewBuilder
    private func allocationBar(label: String, items: [(category: AssetCategory, value: Double)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            StackedHBar(items: items.map {
                StackedHBar.Item(label: $0.category.rawValue, value: $0.value,
                                 color: Palette.color(for: $0.category))
            })
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Account").frame(maxWidth: .infinity, alignment: .leading)
                Text("Owner").frame(width: 110, alignment: .leading)
                Text("Category").frame(width: 90, alignment: .leading)
                Text("Ccy").frame(width: 45, alignment: .leading)
                Text("Baseline").frame(width: 110, alignment: .trailing)
                Text("Scenario").frame(width: 120, alignment: .trailing)
                Text("Δ display").frame(width: 100, alignment: .trailing)
                Text("").frame(width: 30)
            }
            .font(Typo.eyebrow)
            .tracking(1.2)
            .foregroundStyle(Color.lInk3)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.lSunken)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

            ForEach(Array(session.rows.enumerated()), id: \.element.id) { idx, row in
                tableRow(row, idx: idx)
                if idx < session.rows.count - 1 {
                    Divider().overlay(Color.lLine)
                }
            }
        }
    }

    @ViewBuilder
    private func tableRow(_ row: ScenarioSession.Row, idx: Int) -> some View {
        let delta = session.displayDelta(forRow: row, in: ccy)
        let changed = row.isHypothetical || row.scenarioNative != (row.baselineNative ?? 0)
        HStack {
            HStack(spacing: 6) {
                if row.isHypothetical {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.lInk3)
                }
                Text(row.name)
                    .font(Typo.sans(12.5, weight: .medium))
                    .foregroundStyle(Color.lInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.personName)
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk2)
                .frame(width: 110, alignment: .leading)
                .lineLimit(1)
            Text(row.category.rawValue)
                .font(Typo.sans(11.5))
                .foregroundStyle(Color.lInk2)
                .frame(width: 90, alignment: .leading)
            Text(row.currency.rawValue)
                .font(Typo.mono(11))
                .foregroundStyle(Color.lInk3)
                .frame(width: 45, alignment: .leading)
            Text(row.baselineNative.map { Fmt.currency($0, row.currency) } ?? "—")
                .font(Typo.mono(12))
                .foregroundStyle(Color.lInk3)
                .frame(width: 110, alignment: .trailing)
            TextField("", value: Binding(
                get: { row.scenarioNative },
                set: { session.setValue($0, forRow: row.id) }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .font(Typo.mono(12))
            .multilineTextAlignment(.trailing)
            .frame(width: 120)
            Text(delta == 0 ? "—" : Fmt.signedDelta(delta, ccy))
                .font(Typo.mono(11.5, weight: .medium))
                .foregroundStyle(delta == 0 ? Color.lInk4 : (delta > 0 ? Color.lGain : Color.lLoss))
                .frame(width: 100, alignment: .trailing)
                .stealthAmount()
            IconButton(systemName: row.isHypothetical ? "trash" : "arrow.uturn.backward") {
                session.revertRow(row.id)
            }
            .frame(width: 30)
            .opacity(changed ? 1 : 0.25)
            .disabled(!changed)
            .help(row.isHypothetical ? "Remove hypothetical item" : "Revert to baseline")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(changed ? Color.lGainSoft.opacity(0.10) : Color.clear)
    }

    private var addHypotheticalPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                PanelHead(title: "Add hypothetical item",
                          meta: "a purchase, windfall, or new loan")
                HStack(spacing: 10) {
                    TextField("Name — e.g. “Beach house”, “Car loan”", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .font(Typo.sans(12))
                        .frame(maxWidth: 240)
                    Picker("", selection: $newCategory) {
                        ForEach(AssetCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                    Picker("", selection: $newCurrency) {
                        ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 90)
                    TextField("Value", value: $newValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(Typo.mono(12))
                        .frame(width: 120)
                    PrimaryButton(action: addHypothetical) {
                        HStack(spacing: 5) {
                            Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                            Text("Add")
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newValue == 0)
                    Spacer(minLength: 0)
                }
                .padding(18)
            }
        }
    }

    private func addHypothetical() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, newValue != 0 else { return }
        session.addHypothetical(name: trimmed, category: newCategory,
                                currency: newCurrency, value: newValue)
        newName = ""
        newValue = 0
    }

    // MARK: helpers

    private func historyForFit() -> [(Date, Double)] {
        let inc = app.includeIlliquidInNetWorth
        return snapshots
            .sorted { $0.date < $1.date }
            .map { s in
                let total = s.totalsValues.reduce(0.0) {
                    $0 + CurrencyConverter.netDisplayValue(for: $1, in: ccy, includeIlliquid: inc)
                }
                return (s.date, total)
            }
    }

    private func goalDisplay() -> Double? {
        guard app.netWorthGoal > 0 else { return nil }
        if let snap = snapshots.first,
           let v = CurrencyConverter.convert(nativeValue: app.netWorthGoal,
                                             from: app.netWorthGoalCurrency,
                                             to: ccy, in: snap) {
            return v
        }
        return app.netWorthGoalCurrency == ccy ? app.netWorthGoal : nil
    }

    private func etaDeltaText(before: Date?, after: Date?) -> String {
        guard let before, let after else { return "trend not enough data" }
        let months = Calendar.current.dateComponents([.month], from: after, to: before).month ?? 0
        if months == 0 { return "unchanged vs baseline" }
        return months > 0 ? "\(months) mo sooner than baseline" : "\(abs(months)) mo later than baseline"
    }

    private func formatDateLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: d)
    }
}
