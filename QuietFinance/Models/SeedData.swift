import Foundation
import SwiftData

enum SeedData {
    static func seedIfEmpty(context: ModelContext) {
        let personCount = (try? context.fetchCount(FetchDescriptor<Person>())) ?? 0
        guard personCount == 0 else { return }

        // People
        let me = Person(name: "Me")
        let spouse = Person(name: "Spouse")
        context.insert(me); context.insert(spouse)

        // Countries
        let usa = Country(code: "US", name: "USA", flag: "🇺🇸", defaultCurrency: .USD)
        let ind = Country(code: "IN", name: "India", flag: "🇮🇳", defaultCurrency: .INR)
        context.insert(usa); context.insert(ind)

        // Asset types
        let types: [(String, AssetCategory)] = [
            ("Checking", .cash), ("NRO", .cash), ("NRE", .cash), ("FD", .cash),
            ("Stock", .investment), ("MF", .investment),
            ("401k", .retirement), ("IRA", .retirement),
            ("NPS", .retirement), ("HSA", .retirement),
            ("Crypto", .crypto),
            ("Insurance", .insurance),
            ("Home", .realEstate), ("Land", .realEstate), ("Vehicle", .realEstate),
            ("Loan", .debt)
        ]
        var typeMap: [String: AssetType] = [:]
        for (name, cat) in types {
            let t = AssetType(name: name, category: cat)
            context.insert(t)
            typeMap[name] = t
        }

        // Accounts
        let accounts: [(String, Person, Country, String, Currency)] = [
            ("401k Fidelity",   me,     usa, "401k",     .USD),
            ("VTI Brokerage",   me,     usa, "Stock",    .USD),
            ("AAPL Stocks",     me,     usa, "Stock",    .USD),
            ("Chase Checking",  me,     usa, "Checking", .USD),
            ("HSA Fidelity",    me,     usa, "HSA",      .USD),
            ("BTC Coinbase",    me,     usa, "Crypto",   .USD),
            ("ETH Wallet",      me,     usa, "Crypto",   .USD),
            ("NPS Tier-1",      me,     ind, "NPS",      .INR),
            ("NRO Savings",     me,     ind, "NRO",      .INR),
            ("NRE Savings",     me,     ind, "NRE",      .INR),
            ("IRA Vanguard",    spouse, usa, "IRA",      .USD),
            ("MF HDFC Top200",  spouse, ind, "MF",       .INR),
            ("ICICI MF",        spouse, ind, "MF",       .INR),
            ("HDFC Savings",    spouse, ind, "Checking", .INR),
            ("LIC Term",        spouse, ind, "Insurance",.INR)
        ]
        var accMap: [String: Account] = [:]
        for (name, p, c, t, ccy) in accounts {
            let acc = Account(name: name, person: p, country: c, assetType: typeMap[t]!, nativeCurrency: ccy)
            context.insert(acc)
            accMap[name] = acc
        }

        let q4Date = dateFrom("2025-12-31")
        let q1Date = dateFrom("2026-03-31")
        let q4 = Snapshot(date: q4Date, label: formatLabel(q4Date), usdToInrRate: 83.10)
        q4.isLocked = true
        q4.lockedAt = .now
        context.insert(q4)

        let q1 = Snapshot(date: q1Date, label: formatLabel(q1Date), usdToInrRate: 83.25)
        context.insert(q1)

        let q4Values: [(String, Double)] = [
            ("401k Fidelity",   83_800), ("VTI Brokerage",  73_900),
            ("AAPL Stocks",     34_000), ("Chase Checking", 40_000),
            ("HSA Fidelity",    23_050), ("BTC Coinbase",   19_700),
            ("ETH Wallet",      12_000), ("NPS Tier-1",     2_150_000),
            ("NRO Savings",     2_440_000), ("NRE Savings",   980_000),
            ("IRA Vanguard",    39_400), ("MF HDFC Top200", 2_490_000),
            ("ICICI MF",        1_800_000), ("HDFC Savings",   520_000),
            ("LIC Term",        1_160_000)
        ]
        let q1Values: [(String, Double)] = [
            ("401k Fidelity",   92_000), ("VTI Brokerage",  78_000),
            ("AAPL Stocks",     34_000), ("Chase Checking", 42_000),
            ("HSA Fidelity",    24_000), ("BTC Coinbase",   22_000),
            ("ETH Wallet",      12_000), ("NPS Tier-1",     2_330_000),
            ("NRO Savings",     2_330_000), ("NRE Savings",  1_000_000),
            ("IRA Vanguard",    41_000), ("MF HDFC Top200", 2_660_000),
            ("ICICI MF",        1_830_000), ("HDFC Savings",   500_000),
            ("LIC Term",        1_160_000)
        ]
        for (name, v) in q4Values {
            context.insert(AssetValue(snapshot: q4, account: accMap[name]!, nativeValue: v))
        }
        for (name, v) in q1Values {
            context.insert(AssetValue(snapshot: q1, account: accMap[name]!, nativeValue: v))
        }

        try? context.save()
    }

    private static func dateFrom(_ s: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: s) ?? .now
    }

    private static func formatLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }
}
