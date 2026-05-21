import Foundation

enum AccountAnalysis {
    /// Relative tolerance: values considered "same" if within 0.5% of the
    /// reference value (or absolute < 0.01 when reference is ~0). Handles
    /// minor fx rounding while still catching forgotten manual entries.
    static func valuesMatch(_ a: Double, _ b: Double) -> Bool {
        let ref = max(abs(a), abs(b))
        if ref < 0.01 { return abs(a - b) < 0.01 }
        return abs(a - b) / ref < 0.005
    }

    /// Returns true if the account has at least 3 snapshot entries and the
    /// most recent 3 entries (by snapshot date desc) are all within 0.5% of
    /// each other. Likely a forgotten / un-updated balance.
    static func isStale(_ account: Account) -> Bool {
        let entries = account.values
            .compactMap { v -> (Date, Double)? in
                guard let s = v.snapshot else { return nil }
                return (s.date, v.nativeValue)
            }
            .sorted { $0.0 > $1.0 }
        guard entries.count >= 3 else { return false }
        let last3 = Array(entries.prefix(3)).map { $0.1 }
        guard let first = last3.first else { return false }
        return last3.allSatisfy { valuesMatch($0, first) }
    }

    /// Distinct unchanged-value streak (within tolerance) across most recent
    /// snapshots, used to surface "X snapshots unchanged" hint.
    static func unchangedStreak(_ account: Account) -> Int {
        let entries = account.values
            .compactMap { v -> (Date, Double)? in
                guard let s = v.snapshot else { return nil }
                return (s.date, v.nativeValue)
            }
            .sorted { $0.0 > $1.0 }
        guard let first = entries.first else { return 0 }
        var streak = 1
        for i in 1..<entries.count {
            if valuesMatch(entries[i].1, first.1) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
}
