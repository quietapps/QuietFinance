import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let s = String(data: data, encoding: .utf8) {
            self.text = s
        } else {
            self.text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

enum CSVExporter {
    static func flatAssetValues(snapshots: [Snapshot]) -> String {
        let header = [
            "snapshot_date", "snapshot_label", "is_locked", "usd_to_inr_rate",
            "person", "country_code", "country_name", "asset_type", "category",
            "account_name", "institution", "native_currency", "native_value",
            "value_usd", "value_inr", "note"
        ]
        var rows: [[String]] = [header]

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        let sorted = snapshots.sorted { $0.date < $1.date }
        for s in sorted {
            for v in s.values.sorted(by: { ($0.account?.name ?? "") < ($1.account?.name ?? "") }) {
                guard let acc = v.account else { continue }
                let usd = CurrencyConverter.convert(nativeValue: v.nativeValue,
                                                    from: acc.nativeCurrency, to: .USD,
                                                    usdToInrRate: s.usdToInrRate)
                let inr = CurrencyConverter.convert(nativeValue: v.nativeValue,
                                                    from: acc.nativeCurrency, to: .INR,
                                                    usdToInrRate: s.usdToInrRate)
                rows.append([
                    dateFmt.string(from: s.date),
                    s.label,
                    s.isLocked ? "true" : "false",
                    String(format: "%.4f", s.usdToInrRate),
                    acc.person?.name ?? "",
                    acc.country?.code ?? "",
                    acc.country?.name ?? "",
                    acc.assetType?.name ?? "",
                    acc.assetType?.category.rawValue ?? "",
                    acc.name,
                    acc.institution,
                    acc.nativeCurrency.rawValue,
                    String(format: "%.2f", v.nativeValue),
                    String(format: "%.2f", usd),
                    String(format: "%.2f", inr),
                    v.note
                ])
            }
        }
        return encode(rows: rows)
    }

    static func accounts(_ accounts: [Account]) -> String {
        let header = ["name", "person", "country_code", "country_name",
                      "asset_type", "category", "native_currency",
                      "institution", "notes", "active", "cost_basis_native"]
        var rows: [[String]] = [header]
        for a in accounts.sorted(by: { $0.name < $1.name }) {
            rows.append([
                a.name,
                a.person?.name ?? "",
                a.country?.code ?? "",
                a.country?.name ?? "",
                a.assetType?.name ?? "",
                a.assetType?.category.rawValue ?? "",
                a.nativeCurrency.rawValue,
                a.institution,
                a.notes,
                a.isActive ? "true" : "false",
                a.costBasis == 0 ? "" : String(a.costBasis)
            ])
        }
        return encode(rows: rows)
    }

    static func snapshotTotals(snapshots: [Snapshot]) -> String {
        let header = ["snapshot_date", "snapshot_label", "usd_to_inr_rate", "total_usd", "total_inr"]
        var rows: [[String]] = [header]
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        for s in snapshots.sorted(by: { $0.date < $1.date }) {
            let totalUSD = s.values.reduce(0.0) { sum, v in
                guard let acc = v.account else { return sum }
                return sum + CurrencyConverter.convert(nativeValue: v.nativeValue,
                                                       from: acc.nativeCurrency, to: .USD,
                                                       usdToInrRate: s.usdToInrRate)
            }
            let totalINR = totalUSD * s.usdToInrRate
            rows.append([
                dateFmt.string(from: s.date),
                s.label,
                String(format: "%.4f", s.usdToInrRate),
                String(format: "%.2f", totalUSD),
                String(format: "%.2f", totalINR)
            ])
        }
        return encode(rows: rows)
    }

    static func receivables(snapshots: [Snapshot]) -> String {
        let header = [
            "snapshot_date", "snapshot_label", "usd_to_inr_rate",
            "receivable_name", "debtor", "native_currency", "native_value",
            "value_usd", "value_inr", "note"
        ]
        var rows: [[String]] = [header]
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        for s in snapshots.sorted(by: { $0.date < $1.date }) {
            for rv in s.receivableValues.sorted(by: { ($0.receivable?.name ?? "") < ($1.receivable?.name ?? "") }) {
                guard let r = rv.receivable else { continue }
                let usd = CurrencyConverter.convert(nativeValue: rv.nativeValue,
                                                    from: r.nativeCurrency, to: .USD,
                                                    usdToInrRate: s.usdToInrRate)
                let inr = CurrencyConverter.convert(nativeValue: rv.nativeValue,
                                                    from: r.nativeCurrency, to: .INR,
                                                    usdToInrRate: s.usdToInrRate)
                rows.append([
                    dateFmt.string(from: s.date),
                    s.label,
                    String(format: "%.4f", s.usdToInrRate),
                    r.name,
                    r.debtor,
                    r.nativeCurrency.rawValue,
                    String(format: "%.2f", rv.nativeValue),
                    String(format: "%.2f", usd),
                    String(format: "%.2f", inr),
                    rv.note
                ])
            }
        }
        return encode(rows: rows)
    }

    // MARK: encode

    nonisolated private static func encode(rows: [[String]]) -> String {
        rows.map { row in row.map(escape).joined(separator: ",") }.joined(separator: "\n")
    }

    nonisolated private static func escape(_ field: String) -> String {
        let needsQuoting = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        if !needsQuoting { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
