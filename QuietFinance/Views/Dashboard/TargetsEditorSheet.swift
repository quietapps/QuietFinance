import SwiftUI

struct TargetsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: () -> Void

    @State private var drafts: [AssetCategory: String] = [:]
    @State private var initialDrafts: [AssetCategory: String] = [:]
    @State private var showUnsavedConfirm = false

    private var hasChanges: Bool { drafts != initialDrafts }

    private func attemptCancel() {
        if hasChanges { showUnsavedConfirm = true } else { dismiss() }
    }

    private var parsed: [AssetCategory: Double] {
        var out: [AssetCategory: Double] = [:]
        for c in AssetCategory.allCases {
            let s = drafts[c]?.trimmingCharacters(in: .whitespaces) ?? ""
            if !s.isEmpty, let v = Double(s), v >= 0 {
                out[c] = v
            }
        }
        return out
    }

    private var sum: Double { parsed.values.reduce(0, +) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TARGETS")
                    .font(Typo.eyebrow).tracking(1.5)
                    .foregroundStyle(Color.lInk3)
                Text("Target allocation").font(Typo.serifNum(24))
                    .foregroundStyle(Color.lInk)
                Text("Set a target % per category. Actual vs. target variance renders in the composition panel. Leave blank to clear.")
                    .font(Typo.serifItalic(13))
                    .foregroundStyle(Color.lInk2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(AssetCategory.allCases) { c in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Palette.color(for: c))
                            .frame(width: 10, height: 10)
                        Text(c.rawValue)
                            .font(Typo.sans(13, weight: .medium))
                            .foregroundStyle(Color.lInk)
                        Spacer()
                        TextField("—", text: Binding(
                            get: { drafts[c] ?? "" },
                            set: { drafts[c] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(Typo.mono(12))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        Text("%")
                            .font(Typo.sans(12))
                            .foregroundStyle(Color.lInk3)
                            .frame(width: 14, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    Divider().overlay(Color.lLine)
                }
            }

            HStack {
                Text("Sum")
                    .font(Typo.eyebrow).tracking(1.2)
                    .foregroundStyle(Color.lInk3)
                Spacer()
                Text("\(sum, specifier: "%.1f")%")
                    .font(Typo.mono(13, weight: .semibold))
                    .foregroundStyle(sumColor)
                    .monospacedDigit()
                Text(sumHint)
                    .font(Typo.sans(11))
                    .foregroundStyle(Color.lInk3)
            }
            .padding(.top, 4)

            HStack {
                Button("Clear all") {
                    for c in AssetCategory.allCases { drafts[c] = "" }
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .foregroundStyle(Color.lInk3)
                .font(Typo.sans(12))
                Spacer()
                Button("Cancel") { attemptCancel() }
                    .keyboardShortcut(.cancelAction)
                    .pointerStyle(.link)
                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
                .pointerStyle(.link)
            }
            Button("") { save() }
                .keyboardShortcut("s", modifiers: .command)
                .hidden()
                .frame(width: 0, height: 0)
        }
        .padding(24)
        .frame(minWidth: 460)
        .onAppear {
            load()
            initialDrafts = drafts
        }
        .confirmationDialog("Save changes before closing?", isPresented: $showUnsavedConfirm) {
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var sumColor: Color {
        if sum == 0 { return .lInk3 }
        if abs(sum - 100) < 0.01 { return .lGain }
        return .lLoss
    }

    private var sumHint: String {
        if sum == 0 { return "· no targets set" }
        if abs(sum - 100) < 0.01 { return "· balanced" }
        if sum < 100 { return "· \(String(format: "%.1f", 100 - sum))% unassigned" }
        return "· \(String(format: "%.1f", sum - 100))% over"
    }

    private func load() {
        for c in AssetCategory.allCases {
            if let v = TargetAllocationStore.pct(for: c) {
                drafts[c] = String(format: "%g", v)
            } else {
                drafts[c] = ""
            }
        }
    }

    private func save() {
        let p = parsed
        for c in AssetCategory.allCases {
            TargetAllocationStore.setPct(p[c], for: c)
        }
        onSave()
        dismiss()
    }
}
