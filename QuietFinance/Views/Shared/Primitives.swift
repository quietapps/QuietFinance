import SwiftUI
import AppKit

// MARK: - Clickable row helper

extension View {
    /// Tap on row body opens action; inner Buttons keep their own actions
    /// because Button views consume taps before this gesture fires.
    /// Cursor changes to pointing-hand on hover.
    func rowClickable(_ action: @escaping () -> Void) -> some View {
        self
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .pointerStyle(.link)
    }

    /// Mark a button-like element so the cursor reflects clickability.
    func clickableCursor() -> some View {
        self.pointerStyle(.link)
    }
}

// MARK: - Density (compact mode)

private struct CompactModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
extension EnvironmentValues {
    var compactMode: Bool {
        get { self[CompactModeKey.self] }
        set { self[CompactModeKey.self] = newValue }
    }
}

// MARK: - Panel (replaces Card)

struct Panel<Content: View>: View {
    var padding: CGFloat = 0
    let content: () -> Content
    init(padding: CGFloat = 0, @ViewBuilder _ content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }
    var body: some View {
        content()
            .padding(padding)
            .background(Color.lPanel)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.lLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PanelHead: View {
    let title: String
    var meta: String? = nil
    @Environment(\.compactMode) private var compact
    var body: some View {
        HStack {
            Text(title)
                .font(Typo.sans(compact ? 12.5 : 14, weight: .semibold))
                .foregroundStyle(Color.lInk)
            Spacer()
            if let meta {
                Text(meta)
                    .font(Typo.sans(compact ? 10.5 : 12))
                    .foregroundStyle(Color.lInk3)
            }
        }
        .padding(.horizontal, compact ? 14 : 18)
        .padding(.vertical, compact ? 10 : 14)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    let values: [Double]
    var stroke: Color = .lInk
    var fill: Color = .lInk.opacity(0.08)
    var lineWidth: CGFloat = 1.2

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if values.count < 2 {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h / 2))
                    p.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(Color.lInk4, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            } else {
                let minV = values.min() ?? 0
                let maxV = values.max() ?? 1
                let rng = max(maxV - minV, 0.0001)
                let pts: [CGPoint] = values.enumerated().map { (i, v) in
                    let x = Double(i) / Double(values.count - 1) * w
                    let y = h - (v - minV) / rng * h
                    return CGPoint(x: x, y: max(1, min(h - 1, y)))
                }
                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        for pt in pts { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(fill)
                    Path { p in
                        p.move(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(stroke, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

// MARK: - Editorial empty state

struct EditorialEmpty: View {
    let eyebrow: String
    let title: String
    let titleItalic: String?
    let message: String
    let detail: String?
    let ctaLabel: String?
    let cta: (() -> Void)?
    let secondaryLabel: String?
    let secondary: (() -> Void)?
    let illustration: String

    init(eyebrow: String,
         title: String,
         titleItalic: String? = nil,
         body: String,
         detail: String? = nil,
         ctaLabel: String? = nil,
         cta: (() -> Void)? = nil,
         secondaryLabel: String? = nil,
         secondary: (() -> Void)? = nil,
         illustration: String = "tray") {
        self.eyebrow = eyebrow
        self.title = title
        self.titleItalic = titleItalic
        self.message = body
        self.detail = detail
        self.ctaLabel = ctaLabel
        self.cta = cta
        self.secondaryLabel = secondaryLabel
        self.secondary = secondary
        self.illustration = illustration
    }

    var body: some View {
        Panel {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(eyebrow)
                        .font(Typo.eyebrow).tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.lInk3)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(title).font(Typo.serifNum(34))
                            .foregroundStyle(Color.lInk)
                        if let titleItalic {
                            Text(titleItalic).font(Typo.serifItalic(34))
                                .foregroundStyle(Color.lInk3)
                        }
                    }
                    Text(message)
                        .font(Typo.serifItalic(15))
                        .foregroundStyle(Color.lInk2)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 520, alignment: .leading)
                    if let detail {
                        Text(detail)
                            .font(Typo.mono(11))
                            .tracking(0.4)
                            .foregroundStyle(Color.lInk3)
                            .padding(.top, 2)
                    }
                    HStack(spacing: 10) {
                        if let ctaLabel, let cta {
                            PrimaryButton(action: cta) {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                                    Text(ctaLabel)
                                }
                            }
                        }
                        if let secondaryLabel, let secondary {
                            GhostButton(action: secondary) { Text(secondaryLabel) }
                        }
                    }
                    .padding(.top, 6)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(Color.lSunken.opacity(0.6))
                        .frame(width: 132, height: 132)
                    Circle()
                        .stroke(Color.lLine, lineWidth: 1)
                        .frame(width: 132, height: 132)
                    Image(systemName: illustration)
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(Color.lInk3.opacity(0.7))
                }
                .padding(.trailing, 8)
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - SectionHead (page-level)

struct SectionHead: View {
    let title: String
    var emphasis: String? = nil
    var subtitle: String? = nil
    var rightLabel: String? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            HStack(spacing: 6) {
                Text(title).font(Typo.serifNum(28))
                    .foregroundStyle(Color.lInk)
                if let emphasis {
                    Text(emphasis)
                        .font(Typo.serifItalic(28))
                        .foregroundStyle(Color.lInk3)
                }
            }
            Spacer()
            if let rightLabel {
                Text(rightLabel)
                    .font(Typo.eyebrow)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.lInk3)
            }
        }
        if let subtitle {
            Text(subtitle)
                .font(Typo.serifItalic(14))
                .foregroundStyle(Color.lInk3)
                .padding(.top, 2)
        }
    }
}

struct PageHero: View {
    let eyebrow: String
    let title: String
    var titleItalic: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(Typo.eyebrow)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Color.lInk3)
            HStack(spacing: 8) {
                Text(title).font(Typo.serifNum(38))
                if let titleItalic {
                    Text(titleItalic).font(Typo.serifItalic(38))
                        .foregroundStyle(Color.lInk3)
                }
            }
            .foregroundStyle(Color.lInk)
        }
    }
}

// MARK: - KPI card

struct KPICard: View {
    let label: String
    let value: String
    var sub: String? = nil
    var valueColor: Color = .lInk
    var deltaText: String? = nil
    var deltaUp: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typo.eyebrow)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Text(value)
                .font(Typo.serifNum(34))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .stealthAmount()
            if let sub {
                HStack(spacing: 4) {
                    Text(sub)
                        .font(Typo.sans(11))
                        .foregroundStyle(Color.lInk3)
                    if let deltaText {
                        Text(deltaText)
                            .font(Typo.mono(11, weight: .medium))
                            .foregroundStyle(deltaUp ? Color.lGain : Color.lLoss)
                    }
                }
                .stealthAmount()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.lPanel)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.lLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Allocation row (swatch + label + value + pct + bar)

struct AllocRow: View {
    let color: Color
    let label: String
    let value: String
    let pct: Double
    var showBar: Bool = false
    var valueColor: Color = .lInk
    var targetPct: Double? = nil

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(Typo.sans(13, weight: .medium))
                    .foregroundStyle(Color.lInk)
                Spacer()
                if let targetPct {
                    VarianceChip(actual: pct, target: targetPct)
                }
                Text(value)
                    .font(Typo.sans(13, weight: .semibold))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .stealthAmount()
                Text("\(pct, specifier: "%.1f")%")
                    .font(Typo.sans(12))
                    .foregroundStyle(Color.lInk3)
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
            if showBar {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.lSunken)
                        if let targetPct, targetPct > 0 {
                            Rectangle()
                                .fill(Color.lInk3.opacity(0.25))
                                .frame(width: max(0, geo.size.width * CGFloat(min(targetPct, 100) / 100)))
                            Rectangle()
                                .fill(Color.lInk2)
                                .frame(width: 1)
                                .offset(x: max(0, geo.size.width * CGFloat(min(targetPct, 100) / 100)) - 0.5)
                        }
                        Rectangle().fill(color)
                            .frame(width: max(0, geo.size.width * CGFloat(pct / 100)))
                            .opacity(targetPct == nil ? 1 : 0.85)
                    }
                }
                .frame(height: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .padding(.vertical, 6)
    }
}

struct VarianceChip: View {
    let actual: Double
    let target: Double

    var body: some View {
        let delta = actual - target
        let neutral = abs(delta) < 0.1
        let up = delta >= 0
        let tint: Color = neutral ? .lInk3 : (up ? .lGain : .lLoss)
        HStack(spacing: 3) {
            if !neutral {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 8, weight: .bold))
            }
            Text("\(up && !neutral ? "+" : (neutral ? "" : "−"))\(abs(delta), specifier: "%.1f")")
                .font(Typo.mono(10, weight: .semibold))
                .monospacedDigit()
            Text("pp")
                .font(Typo.mono(9))
                .foregroundStyle(tint.opacity(0.7))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(neutral ? 0.05 : 0.12))
        .overlay(Capsule().stroke(tint.opacity(neutral ? 0.2 : 0.35), lineWidth: 1))
        .clipShape(Capsule())
        .help("Target \(String(format: "%.1f", target))% · Actual \(String(format: "%.1f", actual))%")
    }
}

// MARK: - Hero delta pill

struct HeroDelta: View {
    let pct: Double
    let suffix: String
    var body: some View {
        let up = pct >= 0
        HStack(spacing: 6) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text("\(up ? "+" : "−")\(abs(pct), specifier: "%.2f")%")
                .font(Typo.mono(12, weight: .semibold))
            Text(suffix)
                .font(Typo.mono(11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background((up ? Color.lGain : Color.lLoss).opacity(0.12))
        .foregroundStyle(up ? Color.lGain : Color.lLoss)
        .overlay(Capsule().stroke((up ? Color.lGain : Color.lLoss).opacity(0.35), lineWidth: 1))
        .clipShape(Capsule())
    }
}

// MARK: - Avatar (colored disk with initials)

struct Avatar: View {
    let text: String
    var color: Color
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Circle().stroke(color.opacity(0.55), lineWidth: 1)
            Text(text)
                .font(Typo.sans(size * 0.42, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pill

struct Pill: View {
    let text: String
    var emphasis: Bool = false
    var body: some View {
        Text(text)
            .font(Typo.mono(10.5, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(emphasis ? Color.lInk : Color.clear)
            .foregroundStyle(emphasis ? Color.lPanel : Color.lInk2)
            .overlay(Capsule().stroke(emphasis ? Color.lInk : Color.lLine, lineWidth: 1))
            .clipShape(Capsule())
    }
}

struct RateChip: View {
    let leading: String
    let trailing: String
    var body: some View {
        HStack(spacing: 6) {
            Text(leading)
                .font(Typo.mono(10.5))
                .foregroundStyle(Color.lInk3)
            Text(trailing)
                .font(Typo.mono(11, weight: .semibold))
                .foregroundStyle(Color.lInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
    }
}

// MARK: - Segmented control (mono, ink)

struct SegControl<T: Hashable>: View {
    let options: [(label: String, value: T)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                Button {
                    selection = opt.value
                } label: {
                    Text(opt.label)
                        .font(Typo.mono(10.5, weight: .semibold))
                        .foregroundStyle(selection == opt.value ? Color.lPanel : Color.lInk2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selection == opt.value ? Color.lInk : Color.lPanel.opacity(0.001))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                if idx < options.count - 1 {
                    Rectangle().fill(Color.lLine).frame(width: 1, height: 18)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
        .clipShape(Capsule())
    }
}

// MARK: - Primary / Ghost / Icon buttons

struct PrimaryButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action; self.label = label
    }
    var body: some View {
        Button(action: action) {
            label()
                .font(Typo.sans(12, weight: .semibold))
                .foregroundStyle(Color.lPanel)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.lInk)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}

struct GhostButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action; self.label = label
    }
    var body: some View {
        Button(action: action) {
            label()
                .font(Typo.sans(12, weight: .medium))
                .foregroundStyle(Color.lInk)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.lPanel.opacity(0.001))
                .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}

struct IconButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.lInk2)
                .frame(width: 28, height: 28)
                .background(Color.lPanel.opacity(0.001))
                .overlay(Circle().stroke(Color.lLine, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}

// MARK: - Stacked horizontal bar

struct StackedHBar: View {
    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }
    let items: [Item]
    var height: CGFloat = 14

    var body: some View {
        let total = max(0.0001, items.reduce(0) { $0 + abs($1.value) })
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(items) { i in
                    Rectangle()
                        .fill(i.color)
                        .frame(width: max(0, geo.size.width * CGFloat(abs(i.value) / total) - 1))
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - ColorSwatchButton (inline color editor)

struct ColorSwatchButton: View {
    let current: Color
    let onPick: (Color) -> Void
    var size: CGFloat = 14
    @State private var open = false
    @State private var custom: Color = .blue
    @State private var customArmed = false

    var body: some View {
        Button {
            custom = current
            customArmed = false
            open = true
        } label: {
            Circle()
                .fill(current)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.lLine, lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("PICK COLOR")
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(24), spacing: 10), count: 7),
                    spacing: 10
                ) {
                    ForEach(0..<Ink.chart.count, id: \.self) { i in
                        let c = Ink.chart[i].color
                        Button {
                            onPick(c)
                            open = false
                        } label: {
                            Circle()
                                .fill(c)
                                .frame(width: 24, height: 24)
                                .overlay(Circle().stroke(Color.lLine, lineWidth: 1))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                    }
                }
                Divider().overlay(Color.lLine)
                HStack(spacing: 10) {
                    ColorPicker("", selection: $custom, supportsOpacity: false)
                        .labelsHidden()
                    Text("Custom")
                        .font(Typo.sans(12))
                        .foregroundStyle(Color.lInk2)
                    Spacer()
                    PrimaryButton(action: {
                        onPick(custom)
                        NSColorPanel.shared.close()
                        open = false
                    }) { Text("Apply") }
                }
            }
            .padding(14)
            .frame(width: 260)
            .background(Color.lPanel)
            .onChange(of: custom) { _, newVal in
                guard open else { return }
                guard customArmed else { customArmed = true; return }
                onPick(newVal)
                NSColorPanel.shared.close()
                open = false
            }
        }
        .onChange(of: open) { _, isOpen in
            if !isOpen { NSColorPanel.shared.close() }
        }
    }
}

// MARK: - Text helpers

extension View {
    func tabularMono() -> some View {
        self.font(Typo.mono(12)).monospacedDigit()
    }
}
