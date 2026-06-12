import Foundation

/// Subsequence fuzzy matcher for the command palette. Returns nil when the
/// query is not a subsequence of the candidate; otherwise a score where
/// higher is better (prefix start, word-boundary hits, consecutive runs).
enum FuzzyMatch {
    static func score(query: String, candidate: String) -> Double? {
        let q = Array(query.lowercased())
        guard !q.isEmpty else { return 0 }
        let c = Array(candidate.lowercased())
        let original = Array(candidate)

        var score = 0.0
        var qi = 0
        var lastMatch = -2
        for ci in c.indices {
            guard qi < q.count, c[ci] == q[qi] else { continue }
            var bonus = 1.0
            if ci == 0 {
                bonus += 3            // start of string
            } else {
                let prev = original[ci - 1]
                if prev == " " || prev == "·" || prev == "-" || prev == "_" || prev == "/" {
                    bonus += 2        // word boundary
                } else if prev.isLowercase && original[ci].isUppercase {
                    bonus += 2        // camelCase boundary
                }
            }
            if ci == lastMatch + 1 { bonus += 1.5 }   // consecutive run
            score += bonus
            lastMatch = ci
            qi += 1
        }
        guard qi == q.count else { return nil }
        // Mild preference for shorter candidates at equal match quality.
        return score - Double(c.count) * 0.01
    }
}
