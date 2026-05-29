import Foundation

enum FuzzyMatcher {
    /// Ultra-fast fuzzy match scoring.
    /// O(query × candidate) worst case with early exit.
    /// Returns 0 for no match; higher is better.
    static func score(query: String, candidate: String) -> Double {
        let q = query.lowercased()
        let c = candidate.lowercased()
        guard !q.isEmpty, !c.isEmpty else { return 0 }

        if c == q { return 1000 }
        if c.hasPrefix(q) {
            return 500 + (Double(q.count) / Double(c.count)) * 200
        }

        let words = c.components(separatedBy: CharacterSet(charactersIn: " ._-"))
        for word in words {
            if word.hasPrefix(q) {
                return 400 + (Double(q.count) / Double(c.count)) * 150
            }
        }

        if c.contains(q) {
            return 300 + (Double(q.count) / Double(c.count)) * 100
        }

        var qIdx = q.startIndex
        var cIdx = c.startIndex
        var base: Double = 100
        var consecutive: Double = 0
        var lastMatch: String.Index?
        var matched = 0

        while qIdx < q.endIndex && cIdx < c.endIndex {
            if q[qIdx] == c[cIdx] {
                matched += 1
                if let last = lastMatch {
                    let dist = c.distance(from: last, to: cIdx)
                    if dist == 1 { consecutive += 15 }
                    else if dist <= 3 { consecutive += 5 }
                }
                if cIdx == c.startIndex {
                    base += 25
                } else {
                    let prev = c.index(before: cIdx)
                    let pc = c[prev]
                    if pc == " " || pc == "-" || pc == "_" || pc == "." {
                        base += 20
                    }
                }
                lastMatch = cIdx
                q.formIndex(after: &qIdx)
            }
            c.formIndex(after: &cIdx)
        }

        if matched == q.count {
            let gapPenalty = Double(c.count - q.count) * 0.3
            return max(10, base + consecutive - gapPenalty)
        }
        return 0
    }
}
