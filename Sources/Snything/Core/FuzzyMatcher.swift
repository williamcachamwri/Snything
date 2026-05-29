import Foundation

enum FuzzyMatcher {
    /// Ultra-fast fuzzy match scoring.
    /// O(query * candidate) worst case with early exit.
    /// Returns 0 for no match; higher is better.
    static func score(query: String, candidate: String) -> Double {
        let q = query.lowercased()
        let c = candidate.lowercased()
        guard !q.isEmpty, !c.isEmpty else { return 0 }
        let qCount = q.count
        let cCount = c.count
        guard qCount <= cCount else { return 0 }

        if c == q { return 1000 }
        if c.hasPrefix(q) {
            return 500 + (Double(qCount) / Double(cCount)) * 200
        }

        // Word boundary prefix check
        let separators: CharacterSet = [" ", "_", "-", "."]
        var inWord = false
        var wordStart = c.startIndex
        for (i, ch) in c.enumerated() {
            let idx = c.index(c.startIndex, offsetBy: i)
            if separators.contains(ch.unicodeScalars.first!) {
                if inWord {
                    let word = String(c[wordStart..<idx])
                    if word.hasPrefix(q) {
                        return 400 + (Double(qCount) / Double(cCount)) * 150
                    }
                }
                inWord = false
            } else if !inWord {
                inWord = true
                wordStart = idx
            }
        }
        if inWord {
            let lastWord = String(c[wordStart...])
            if lastWord.hasPrefix(q) {
                return 400 + (Double(qCount) / Double(cCount)) * 150
            }
        }

        if c.contains(q) {
            return 300 + (Double(qCount) / Double(cCount)) * 100
        }

        // Fuzzy: all query chars in order
        var qi = 0
        var ci = 0
        var matched = 0
        var lastMatchCi = -1
        var consecutive: Double = 0

        let qChars = Array(q)
        let cChars = Array(c)

        while qi < qCount && ci < cCount {
            if qChars[qi] == cChars[ci] {
                matched += 1
                if lastMatchCi >= 0 {
                    let dist = ci - lastMatchCi
                    if dist == 1 { consecutive += 15 }
                    else if dist <= 3 { consecutive += 5 }
                }
                lastMatchCi = ci
                qi += 1
            }
            ci += 1
        }

        guard matched == qCount else { return 0 }
        let gapPenalty = Double(cCount - qCount) * 0.3
        return max(10, 100 + consecutive - gapPenalty)
    }
}


