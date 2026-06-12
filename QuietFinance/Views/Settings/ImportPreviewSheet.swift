import SwiftUI

/// Pre-import review: detected format, row counts, what would be created,
/// sample rows, and per-line issues — commit only on explicit confirm.
struct ImportPreviewSheet: View {
    let preview: CSVImporter.Preview
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("IMPORT PREVIEW")
                    .font(Typo.eyebrow).tracking(1.5).foregroundStyle(Color.lInk3)
                HStack(spacing: 10) {
                    Text("Review before import")
                        .font(Typo.serifNum(24))
                        .foregroundStyle(Color.lInk)
                    Pill(text: preview.format.rawValue, emphasis: true)
                }
                Text("Nothing has been written yet — confirm below to commit.")
                    .font(Typo.serifItalic(12.5))
                    .foregroundStyle(Color.lInk3)
            }
            .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 16)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 22) {
                        stat("ROWS", "\(preview.dataRowCount)")
                        stat("VALID", "\(preview.validRowCount)",
                             tint: preview.validRowCount == preview.dataRowCount ? .lGain : .lInk)
                        stat("ISSUES", "\(preview.issues.count)",
                             tint: preview.issues.isEmpty ? .lInk3 : .lLoss)
                        if preview.estimatedNewSnapshots > 0 {
                            stat("NEW SNAPSHOTS", "\(preview.estimatedNewSnapshots)")
                        }
                        if preview.estimatedNewAccounts > 0 {
                            stat("NEW ACCOUNTS", "\(preview.estimatedNewAccounts)")
                        }
                        if preview.estimatedNewPeople > 0 {
                            stat("NEW PEOPLE", "\(preview.estimatedNewPeople)")
                        }
                        Spacer(minLength: 0)
                    }

                    if !preview.issues.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ISSUES — THESE ROWS WILL BE SKIPPED")
                                .font(Typo.eyebrow).tracking(1.2)
                                .foregroundStyle(Color.lLoss)
                            ForEach(Array(preview.issues.prefix(10).enumerated()), id: \.offset) { _, issue in
                                Text(issue)
                                    .font(Typo.mono(11))
                                    .foregroundStyle(Color.lLoss)
                            }
                            if preview.issues.count > 10 {
                                Text("…and \(preview.issues.count - 10) more.")
                                    .font(Typo.mono(11))
                                    .foregroundStyle(Color.lInk3)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.lLossSoft.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("SAMPLE — FIRST \(preview.sampleRows.count) ROWS")
                            .font(Typo.eyebrow).tracking(1.2)
                            .foregroundStyle(Color.lInk3)
                        ScrollView(.horizontal) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preview.header.joined(separator: "  ·  "))
                                    .font(Typo.mono(10, weight: .semibold))
                                    .foregroundStyle(Color.lInk2)
                                ForEach(Array(preview.sampleRows.enumerated()), id: \.offset) { _, row in
                                    Text(row.joined(separator: "  ·  "))
                                        .font(Typo.mono(10))
                                        .foregroundStyle(Color.lInk3)
                                        .lineLimit(1)
                                }
                            }
                            .padding(10)
                        }
                        .background(Color.lSunken.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(24)
            }
            .frame(maxHeight: 380)

            Divider().overlay(Color.lLine)
            HStack {
                Spacer()
                GhostButton(action: onCancel) { Text("Cancel") }
                PrimaryButton(action: onConfirm) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 10, weight: .bold))
                        Text("Import \(preview.validRowCount) rows")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(preview.validRowCount == 0)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .background(Color.lBg)
        .frame(minWidth: 640)
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String, tint: Color = .lInk) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
            Text(value)
                .font(Typo.serifNum(20))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }
}
