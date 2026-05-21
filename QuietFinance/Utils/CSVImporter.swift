import Foundation
import SwiftData

enum CSVImporter {
    struct Report {
        var snapshotsCreated = 0
        var snapshotsSkipped = 0
        var accountsCreated = 0
        var accountsUpdated = 0
        var accountsUnchanged = 0
        var peopleCreated = 0
        var countriesCreated = 0
        var typesCreated = 0
        var valuesCreated = 0
        var valuesSkipped = 0
        var rowsRejected = 0
        var errors: [String] = []

        var summary: String {
            var parts: [String] = []
            if snapshotsCreated > 0 { parts.append("\(snapshotsCreated) snapshots") }
            if accountsCreated > 0  { parts.append("\(accountsCreated) accounts") }
            if peopleCreated > 0    { parts.append("\(peopleCreated) people") }
            if countriesCreated > 0 { parts.append("\(countriesCreated) countries") }
            if typesCreated > 0     { parts.append("\(typesCreated) types") }
            if valuesCreated > 0    { parts.append("\(valuesCreated) values") }
            let created = parts.isEmpty ? "nothing new" : parts.joined(separator: ", ")
            var s = "Imported \(created)."
            if accountsUpdated > 0   { s += " \(accountsUpdated) accounts updated." }
            if accountsUnchanged > 0 { s += " \(accountsUnchanged) accounts unchanged." }
            if valuesSkipped > 0    { s += " \(valuesSkipped) values already existed." }
            if rowsRejected > 0     { s += " \(rowsRejected) rows rejected." }
            return s
        }
    }

    enum ImportError: LocalizedError {
        case emptyFile
        case missingHeader(String)
        case parseError(String)
        case unknownFormat

        var errorDescription: String? {
            switch self {
            case .emptyFile:               return "File is empty."
            case .missingHeader(let col):  return "Expected column “\(col)” missing from header."
            case .parseError(let msg):     return "Parse error: \(msg)"
            case .unknownFormat:           return "Unrecognized CSV format. Expected Full history or Accounts list export."
            }
        }
    }

    // MARK: - Public entry

    /// Auto-detect CSV format (Full history vs Accounts list) and dispatch.
    static func importAuto(csv: String, context: ModelContext) throws -> Report {
        let rows = try parseCSV(csv)
        guard let first = rows.first else { throw ImportError.emptyFile }
        let header = first.map { $0.trimmingCharacters(in: .whitespaces) }
        if header.contains("snapshot_date") {
            return try importFlatHistory(csv: csv, context: context)
        }
        if header.contains("name") && header.contains("asset_type") && header.contains("country_code") {
            return try importAccounts(csv: csv, context: context)
        }
        throw ImportError.unknownFormat
    }

    /// Import the accounts schema exported by CSVExporter.accounts.
    /// Header: name, person, country_code, country_name, asset_type, category,
    ///         native_currency, institution, notes, active, cost_basis_native
    /// Accounts are matched by (lowercased name, person id, country id). Existing
    /// accounts are left as-is; new accounts are created. Person, country, and
    /// asset type are created on demand.
    static func importAccounts(csv: String, context: ModelContext) throws -> Report {
        let rows = try parseCSV(csv)
        guard rows.count >= 2 else { throw ImportError.emptyFile }
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespaces) }
        let data = Array(rows.dropFirst())

        func idx(_ name: String) throws -> Int {
            guard let i = header.firstIndex(of: name) else {
                throw ImportError.missingHeader(name)
            }
            return i
        }
        func optIdx(_ name: String) -> Int? { header.firstIndex(of: name) }

        let iName    = try idx("name")
        let iPerson  = try idx("person")
        let iCC      = try idx("country_code")
        let iCName   = try idx("country_name")
        let iType    = try idx("asset_type")
        let iCat     = try idx("category")
        let iCcy     = try idx("native_currency")
        let iInst    = try idx("institution")
        let iNote    = optIdx("notes")
        let iActive  = optIdx("active")
        let iCost    = optIdx("cost_basis_native")

        var report = Report()

        var peopleByName = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Person>())) ?? [])
                .map { ($0.name, $0) }
        )
        var countriesByCode = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Country>())) ?? [])
                .map { ($0.code, $0) }
        )
        var typesByName = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<AssetType>())) ?? [])
                .map { ($0.name, $0) }
        )
        func acctKey(name: String, personID: UUID?, countryID: UUID?) -> String {
            "\(name.lowercased())|\(personID?.uuidString ?? "_")|\(countryID?.uuidString ?? "_")"
        }
        var accountsByKey: [String: Account] = [:]
        for a in (try? context.fetch(FetchDescriptor<Account>())) ?? [] {
            accountsByKey[acctKey(name: a.name, personID: a.person?.id, countryID: a.country?.id)] = a
        }

        for (ri, row) in data.enumerated() {
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            let lineNum = ri + 2

            guard row.count >= header.count else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): too few columns.")
                continue
            }

            let accountName = row[iName].trimmingCharacters(in: .whitespaces)
            guard !accountName.isEmpty else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): empty name.")
                continue
            }
            let personName = row[iPerson].trimmingCharacters(in: .whitespaces)
            let cc = row[iCC].trimmingCharacters(in: .whitespaces)
            let cname = row[iCName].trimmingCharacters(in: .whitespaces)
            let typeName = row[iType].trimmingCharacters(in: .whitespaces)
            let catStr = row[iCat].trimmingCharacters(in: .whitespaces)
            let ccyStr = row[iCcy].trimmingCharacters(in: .whitespaces)
            let institution = row[iInst]
            let notes = iNote.map { row[$0] } ?? ""
            let isActive: Bool = {
                guard let i = iActive else { return true }
                let s = row[i].trimmingCharacters(in: .whitespaces).lowercased()
                if s.isEmpty { return true }
                return s == "true" || s == "1" || s == "yes"
            }()
            let costBasis: Double = {
                guard let i = iCost else { return 0 }
                let s = row[i].trimmingCharacters(in: .whitespaces)
                return Double(s) ?? 0
            }()

            guard let currency = Currency(rawValue: ccyStr) else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): unknown currency “\(ccyStr)”.")
                continue
            }

            let person: Person? = {
                guard !personName.isEmpty else { return nil }
                if let p = peopleByName[personName] { return p }
                let p = Person(name: personName)
                context.insert(p)
                peopleByName[personName] = p
                report.peopleCreated += 1
                return p
            }()

            let country: Country? = {
                guard !cc.isEmpty else { return nil }
                if let c = countriesByCode[cc] { return c }
                let defaultCcy: Currency = cc.uppercased() == "IN" ? .INR : .USD
                let c = Country(
                    code: cc,
                    name: cname.isEmpty ? cc : cname,
                    flag: "",
                    defaultCurrency: defaultCcy
                )
                context.insert(c)
                countriesByCode[cc] = c
                report.countriesCreated += 1
                return c
            }()

            let type: AssetType? = {
                guard !typeName.isEmpty else { return nil }
                if let t = typesByName[typeName] { return t }
                let cat = AssetCategory(rawValue: catStr) ?? .cash
                let t = AssetType(name: typeName, category: cat)
                context.insert(t)
                typesByName[typeName] = t
                report.typesCreated += 1
                return t
            }()

            let key = acctKey(name: accountName, personID: person?.id, countryID: country?.id)
            if let existing = accountsByKey[key] {
                var changed = false
                if existing.nativeCurrency != currency { existing.nativeCurrency = currency; changed = true }
                if existing.institution != institution { existing.institution = institution; changed = true }
                if existing.notes != notes { existing.notes = notes; changed = true }
                if existing.isActive != isActive { existing.isActive = isActive; changed = true }
                if existing.costBasis != costBasis { existing.costBasis = costBasis; changed = true }
                if let type, existing.assetType?.id != type.id { existing.assetType = type; changed = true }
                if changed { report.accountsUpdated += 1 } else { report.accountsUnchanged += 1 }
                continue
            }
            guard let person, let country, let type else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): cannot create account “\(accountName)” without person/country/type.")
                continue
            }
            let a = Account(
                name: accountName,
                person: person,
                country: country,
                assetType: type,
                nativeCurrency: currency,
                institution: institution,
                notes: notes,
                isActive: isActive
            )
            a.costBasis = costBasis
            context.insert(a)
            accountsByKey[key] = a
            report.accountsCreated += 1
        }

        try context.save()
        return report
    }

    /// Import the flatAssetValues schema exported by CSVExporter.flatAssetValues.
    static func importFlatHistory(csv: String, context: ModelContext) throws -> Report {
        let rows = try parseCSV(csv)
        guard rows.count >= 2 else { throw ImportError.emptyFile }
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespaces) }
        let data = Array(rows.dropFirst())

        func idx(_ name: String) throws -> Int {
            guard let i = header.firstIndex(of: name) else {
                throw ImportError.missingHeader(name)
            }
            return i
        }

        let iDate    = try idx("snapshot_date")
        let iLabel   = try idx("snapshot_label")
        let iLocked  = try idx("is_locked")
        let iRate    = try idx("usd_to_inr_rate")
        let iPerson  = try idx("person")
        let iCC      = try idx("country_code")
        let iCName   = try idx("country_name")
        let iType    = try idx("asset_type")
        let iCat     = try idx("category")
        let iAccount = try idx("account_name")
        let iInst    = try idx("institution")
        let iCcy     = try idx("native_currency")
        let iNative  = try idx("native_value")
        let iNote    = try idx("note")

        var report = Report()

        // Preload existing entities for lookup
        var peopleByName = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Person>())) ?? [])
                .map { ($0.name, $0) }
        )
        var countriesByCode = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Country>())) ?? [])
                .map { ($0.code, $0) }
        )
        var typesByName = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<AssetType>())) ?? [])
                .map { ($0.name, $0) }
        )
        func acctKey(name: String, personID: UUID?, countryID: UUID?) -> String {
            "\(name.lowercased())|\(personID?.uuidString ?? "_")|\(countryID?.uuidString ?? "_")"
        }
        var accountsByKey: [String: Account] = [:]
        for a in (try? context.fetch(FetchDescriptor<Account>())) ?? [] {
            accountsByKey[acctKey(name: a.name, personID: a.person?.id, countryID: a.country?.id)] = a
        }
        var snapshotsByDate = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Snapshot>())) ?? [])
                .map { (Calendar.current.startOfDay(for: $0.date), $0) }
        )

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        for (ri, row) in data.enumerated() {
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            let lineNum = ri + 2 // +1 for header, +1 for 1-index

            guard row.count >= header.count else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): too few columns.")
                continue
            }

            let dateStr = row[iDate].trimmingCharacters(in: .whitespaces)
            guard let date = dateFmt.date(from: dateStr).map({ Calendar.current.startOfDay(for: $0) }) else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): invalid date “\(dateStr)”.")
                continue
            }

            let label = row[iLabel].trimmingCharacters(in: .whitespaces)
            let isLocked = row[iLocked].lowercased() == "true"
            guard let rate = Double(row[iRate].trimmingCharacters(in: .whitespaces)), rate > 0 else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): invalid rate.")
                continue
            }
            let personName = row[iPerson].trimmingCharacters(in: .whitespaces)
            let cc = row[iCC].trimmingCharacters(in: .whitespaces)
            let cname = row[iCName].trimmingCharacters(in: .whitespaces)
            let typeName = row[iType].trimmingCharacters(in: .whitespaces)
            let catStr = row[iCat].trimmingCharacters(in: .whitespaces)
            let accountName = row[iAccount].trimmingCharacters(in: .whitespaces)
            let institution = row[iInst]
            let ccyStr = row[iCcy].trimmingCharacters(in: .whitespaces)
            guard let native = Double(row[iNative].trimmingCharacters(in: .whitespaces)) else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): invalid native_value.")
                continue
            }
            let note = row[iNote]
            guard !accountName.isEmpty else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): empty account_name.")
                continue
            }
            guard let currency = Currency(rawValue: ccyStr) else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): unknown currency “\(ccyStr)”.")
                continue
            }

            // Person
            let person: Person? = {
                guard !personName.isEmpty else { return nil }
                if let p = peopleByName[personName] { return p }
                let p = Person(name: personName)
                context.insert(p)
                peopleByName[personName] = p
                report.peopleCreated += 1
                return p
            }()

            // Country
            let country: Country? = {
                guard !cc.isEmpty else { return nil }
                if let c = countriesByCode[cc] { return c }
                let defaultCcy: Currency = cc.uppercased() == "IN" ? .INR : .USD
                let c = Country(
                    code: cc,
                    name: cname.isEmpty ? cc : cname,
                    flag: "",
                    defaultCurrency: defaultCcy
                )
                context.insert(c)
                countriesByCode[cc] = c
                report.countriesCreated += 1
                return c
            }()

            // AssetType
            let type: AssetType? = {
                guard !typeName.isEmpty else { return nil }
                if let t = typesByName[typeName] { return t }
                let cat = AssetCategory(rawValue: catStr) ?? .cash
                let t = AssetType(name: typeName, category: cat)
                context.insert(t)
                typesByName[typeName] = t
                report.typesCreated += 1
                return t
            }()

            // Account — require person, country, type to create (matches Account.init)
            let account: Account? = {
                let key = acctKey(name: accountName, personID: person?.id, countryID: country?.id)
                if let a = accountsByKey[key] { return a }
                guard let person, let country, let type else { return nil }
                let a = Account(
                    name: accountName,
                    person: person,
                    country: country,
                    assetType: type,
                    nativeCurrency: currency,
                    institution: institution,
                    notes: "",
                    isActive: true
                )
                context.insert(a)
                accountsByKey[key] = a
                report.accountsCreated += 1
                return a
            }()
            guard let account else {
                report.rowsRejected += 1
                report.errors.append("Line \(lineNum): cannot create account “\(accountName)” without person/country/type.")
                continue
            }

            // Snapshot
            let snapshot: Snapshot = {
                if let s = snapshotsByDate[date] {
                    report.snapshotsSkipped += 1
                    return s
                }
                let s = Snapshot(
                    date: date,
                    label: label.isEmpty ? dateFmt.string(from: date) : label,
                    usdToInrRate: rate
                )
                s.isLocked = isLocked
                if isLocked { s.lockedAt = .now }
                context.insert(s)
                snapshotsByDate[date] = s
                report.snapshotsCreated += 1
                return s
            }()

            // AssetValue — skip if one already exists for this (snapshot, account)
            let already = snapshot.values.contains { $0.account?.id == account.id }
            if already {
                report.valuesSkipped += 1
            } else {
                let av = AssetValue(snapshot: snapshot, account: account, nativeValue: native, note: note)
                context.insert(av)
                report.valuesCreated += 1
            }
        }

        try context.save()
        return report
    }

    // MARK: - CSV parser (RFC-4180 subset; handles quoted fields, escaped quotes, newlines)

    static func parseCSV(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var i = text.startIndex

        while i < text.endIndex {
            let c = text[i]
            if inQuotes {
                if c == "\"" {
                    let next = text.index(after: i)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        i = text.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                        i = next
                        continue
                    }
                } else {
                    field.append(c)
                    i = text.index(after: i)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                    i = text.index(after: i)
                case ",":
                    row.append(field)
                    field = ""
                    i = text.index(after: i)
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                    i = text.index(after: i)
                case "\r":
                    let next = text.index(after: i)
                    if next < text.endIndex, text[next] == "\n" {
                        row.append(field)
                        rows.append(row)
                        row = []
                        field = ""
                        i = text.index(after: next)
                    } else {
                        row.append(field)
                        rows.append(row)
                        row = []
                        field = ""
                        i = next
                    }
                default:
                    field.append(c)
                    i = text.index(after: i)
                }
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
