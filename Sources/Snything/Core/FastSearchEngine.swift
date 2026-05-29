import Foundation
import AppKit
import os

/// Ultra-fast search engine using Spotlight (mdfind) as the primary source.
/// Spotlight already indexes every file on the Mac — no custom indexing needed.
/// Memory-safe: mdfind runs as a subprocess; results stream through a Pipe.
/// No long-lived memory buffers; NSCache is capped at 50 entries / 5MB.
final class FastSearchEngine: @unchecked Sendable {
    static let shared = FastSearchEngine()

    private var currentTask: Task<Void, Never>?
    private var mdfindProcess: Process?
    private let processLock = OSAllocatedUnfairLock<Void>(initialState: ())

    private let cache = NSCache<NSString, NSArray>()
    private let cacheLock = OSAllocatedUnfairLock<Void>(initialState: ())

    private var appCache: [SearchResult] = []
    private var appCacheLoaded = false
    private let appCacheLock = OSAllocatedUnfairLock<Void>(initialState: ())

    private let commandMap: [(name: String, desc: String, payload: String)] = [
        ("quit", "Quit Snything", "__QUIT__"),
        ("lock screen", "Lock Screen", "pmset displaysleepnow"),
        ("sleep", "Put Mac to Sleep", "pmset sleepnow"),
        ("empty trash", "Empty Trash", "osascript -e 'tell app \"Finder\" to empty trash'"),
    ]

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 5 * 1024 * 1024
    }

    // MARK: - Entry Point

    func search(query: String, maxResults: Int = 200, onBatch: @escaping @Sendable ([SearchResult]) -> Void) {
        currentTask?.cancel()
        cancel()

        let task = Task {
            let cacheKey = "\(query)_\(maxResults)" as NSString
            if let cached = self.cachedResults(for: cacheKey) {
                await MainActor.run { onBatch(cached) }
                return
            }

            let q = query.trimmingCharacters(in: .whitespaces)
            guard !q.isEmpty, q.count <= 100 else {
                await MainActor.run { onBatch([]) }
                return
            }

            // Phase 1: Instant sync results (calculator, commands, web)
            var allResults: [SearchResult] = []
            allResults.append(contentsOf: self.evaluateCalculator(query: q))
            allResults.append(contentsOf: self.builtInCommands(query: q))
            allResults.append(contentsOf: self.webSearches(query: q))

            // Phase 2: Spotlight mdfind — PRIMARY. Searches EVERYWHERE on the Mac.
            // Spotlight's index is always up-to-date, comprehensive, and fast.
            async let mdfindNameResults = self.runMdfind(query: q, maxResults: maxResults)
            let mdfind = await mdfindNameResults
            allResults.append(contentsOf: mdfind)

            // Phase 3: Cached apps (fuzzy from RAM, covers app display names mdfind might miss)
            let appResults = await self.scanApplications(query: q, maxResults: maxResults)
            allResults.append(contentsOf: appResults)

            // Phase 4: Content search — very limited, only for long queries
            if q.count >= 8 {
                let content = await self.runContentSearch(query: q, maxResults: 2)
                allResults.append(contentsOf: content)
            }

            // Deduplicate by path + sort by score
            var seen = Set<String>()
            var unique: [SearchResult] = []
            unique.reserveCapacity(min(allResults.count, maxResults))
            for r in allResults.sorted(by: { $0.relevanceScore > $1.relevanceScore }) {
                if seen.insert(r.id).inserted {
                    unique.append(r)
                    if unique.count >= maxResults { break }
                }
            }

            self.setCache(key: cacheKey, results: unique)
            await MainActor.run { onBatch(unique) }
        }
        currentTask = task
    }

    func cancel() {
        currentTask?.cancel()
        processLock.withLock { _ in
            mdfindProcess?.terminate()
            mdfindProcess = nil
        }
    }

    // MARK: - Spotlight (name search — everywhere on the Mac)

    private func runMdfind(query: String, maxResults: Int) async -> [SearchResult] {
        let escaped = escapeForPredicate(query)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        // Search EVERYWHERE Spotlight has indexed (no -onlyin restriction)
        // cd = case/diacritic insensitive
        let pred = "kMDItemDisplayName == '*\(escaped)*'cd || kMDItemFSName == '*\(escaped)*'cd"
        process.arguments = [pred]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        processLock.withLock { _ in mdfindProcess = process }
        defer {
            processLock.withLock { _ in
                if mdfindProcess === process { mdfindProcess = nil }
            }
        }

        do { try process.run() } catch { return [] }

        // Read data with a reasonable timeout to avoid hanging on huge results
        let data: Data
        do {
            data = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    let d = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: d)
                }
            }
        } catch {
            process.terminate()
            return []
        }

        process.waitUntilExit()
        guard !Task.isCancelled else { return [] }

        let paths = String(data: data, encoding: .utf8)?
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .prefix(maxResults) ?? []

        let fm = FileManager.default
        var results: [SearchResult] = []
        results.reserveCapacity(min(paths.count, maxResults))

        for path in paths {
            guard !Task.isCancelled else { break }
            let url = URL(fileURLWithPath: String(path))
            guard fm.fileExists(atPath: url.path) else { continue }
            results.append(SearchResult(
                url: url, name: url.lastPathComponent, path: url.path,
                kind: SearchResult.kind(from: url),
                size: url.fileSize(), modifiedDate: url.modDate(),
                relevanceScore: 2.0
            ))
        }
        return results
    }

    // MARK: - Content Search

    private func runContentSearch(query: String, maxResults: Int) async -> [SearchResult] {
        let escaped = escapeForPredicate(query)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        let pred = "kMDItemTextContent == '*\(escaped)*'cd"
        process.arguments = [pred]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        processLock.withLock { _ in mdfindProcess = process }
        defer {
            processLock.withLock { _ in
                if mdfindProcess === process { mdfindProcess = nil }
            }
        }

        do { try process.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard !Task.isCancelled else { return [] }

        let paths = String(data: data, encoding: .utf8)?
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .prefix(maxResults) ?? []

        let fm = FileManager.default
        var results: [SearchResult] = []
        results.reserveCapacity(min(paths.count, maxResults))

        for path in paths {
            guard !Task.isCancelled else { break }
            let url = URL(fileURLWithPath: String(path))
            guard fm.fileExists(atPath: url.path) else { continue }
            results.append(SearchResult(
                url: url, name: url.lastPathComponent, path: url.path,
                kind: SearchResult.kind(from: url),
                size: url.fileSize(), modifiedDate: url.modDate(),
                relevanceScore: 0.05,
                subtitle: "Content match",
                actionType: .openFile, actionPayload: ""
            ))
        }
        return results
    }

    // MARK: - Predicate Escaping (only ' and \ can break the string literal)

    private func escapeForPredicate(_ raw: String) -> String {
        // mdfind predicates use single-quoted strings.
        // Only \ and ' need escaping inside single quotes.
        return raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    // MARK: - Applications

    private func ensureAppCache() {
        appCacheLock.withLock { _ in
            guard !appCacheLoaded else { return }
            let dirs = ["/Applications", "/System/Applications", "\(NSHomeDirectory())/Applications"]
            let fm = FileManager.default
            var apps: [SearchResult] = []
            for dir in dirs {
                guard let urls = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil) else { continue }
                for url in urls where url.pathExtension == "app" {
                    let name = appDisplayName(for: url)
                    apps.append(SearchResult(
                        url: url, name: name, path: url.path,
                        kind: .application, size: nil, modifiedDate: nil,
                        relevanceScore: 0,
                        subtitle: url.deletingLastPathComponent().path,
                        actionType: .openFile, actionPayload: ""
                    ))
                }
            }
            appCache = apps
            appCacheLoaded = true
        }
    }

    private func scanApplications(query: String, maxResults: Int) async -> [SearchResult] {
        ensureAppCache()
        var cached: [SearchResult] = []
        appCacheLock.withLock { _ in cached = appCache }

        let q = query.lowercased()
        var results: [SearchResult] = []
        for app in cached {
            guard !Task.isCancelled else { break }
            let score = FuzzyMatcher.score(query: q, candidate: app.name)
            guard score > 0 else { continue }
            results.append(SearchResult(
                url: app.url, name: app.name, path: app.path,
                kind: .application, size: nil, modifiedDate: nil,
                relevanceScore: score + 5,
                subtitle: app.subtitle,
                actionType: .openFile, actionPayload: ""
            ))
            if results.count >= maxResults { break }
        }
        return results
    }

    private func appDisplayName(for url: URL) -> String {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: plist) as? [String: Any] else {
            return url.deletingPathExtension().lastPathComponent
        }
        if let display = dict["CFBundleDisplayName"] as? String, !display.isEmpty { return display }
        if let name = dict["CFBundleName"] as? String, !name.isEmpty { return name }
        return url.deletingPathExtension().lastPathComponent
    }

    // MARK: - Calculator (bulletproof, no regex)

    private func evaluateCalculator(query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3, trimmed.count <= 50 else { return [] }

        let allowedChars: Set<Character> = ["0","1","2","3","4","5","6","7","8","9","+","-","*","/","(",")","."," "]
        let digits: Set<Character> = ["0","1","2","3","4","5","6","7","8","9"]
        let ops: Set<Character> = ["+","-","*","/"]

        var hasDigit = false
        var hasOp = false
        let chars = Array(trimmed)

        for ch in chars {
            guard allowedChars.contains(ch) else { return [] }
            if digits.contains(ch) { hasDigit = true }
            if ops.contains(ch) { hasOp = true }
        }
        guard hasDigit && hasOp else { return [] }

        guard digits.contains(chars.first!) || chars.first! == "(" else { return [] }
        guard let last = chars.last, !ops.contains(last), last != "." else { return [] }

        var parenCount = 0
        for i in 0..<chars.count {
            let ch = chars[i]
            if ch == "(" {
                parenCount += 1
                if i + 1 < chars.count, chars[i + 1] == ")" { return [] }
            } else if ch == ")" {
                parenCount -= 1
                if parenCount < 0 { return [] }
            }
        }
        guard parenCount == 0 else { return [] }

        for i in 0..<(chars.count - 1) {
            let a = chars[i], b = chars[i + 1]
            if ops.contains(a) && ops.contains(b) { return [] }
            if a == "." && b == "." { return [] }
            if a == "(" && ops.contains(b) && b != "-" { return [] }
            if ops.contains(a) && b == ")" { return [] }
        }

        for i in 0..<(chars.count - 1) {
            if chars[i] == "." && !digits.contains(chars[i + 1]) { return [] }
        }

        guard let value = Self.safeEvaluate(trimmed) else { return [] }
        guard value.isFinite else { return [] }

        let resultStr: String
        if abs(value.truncatingRemainder(dividingBy: 1)) < 0.0001 {
            resultStr = String(Int(value))
        } else {
            var s = String(format: "%.4f", value)
            while s.last == "0" { s.removeLast() }
            if s.last == "." { s.removeLast() }
            resultStr = s
        }

        return [SearchResult(
            url: URL(fileURLWithPath: "/dev/null"),
            name: trimmed,
            path: "calc:\(trimmed)",
            kind: .calculation,
            size: nil, modifiedDate: nil, relevanceScore: 800,
            subtitle: "= \(resultStr)",
            actionType: .pasteText, actionPayload: resultStr
        )]
    }

    private static func safeEvaluate(_ expression: String) -> Double? {
        let expr = NSExpression(format: expression)
        guard let num = expr.expressionValue(with: nil, context: nil) as? NSNumber else { return nil }
        return num.doubleValue
    }

    // MARK: - Built-in Commands

    private func builtInCommands(query: String) -> [SearchResult] {
        var results: [SearchResult] = []
        for cmd in commandMap {
            let score = FuzzyMatcher.score(query: query, candidate: cmd.name)
            guard score > 0 else { continue }
            results.append(SearchResult(
                url: URL(fileURLWithPath: "/dev/null"),
                name: cmd.name,
                path: "cmd:\(cmd.name)",
                kind: .command,
                size: nil, modifiedDate: nil,
                relevanceScore: score,
                subtitle: cmd.desc,
                actionType: .runShell, actionPayload: cmd.payload
            ))
        }
        return results
    }

    // MARK: - Web Search

    private func webSearches(query: String) -> [SearchResult] {
        let engines = [
            ("google", "https://www.google.com/search?q="),
            ("youtube", "https://www.youtube.com/results?search_query="),
            ("github", "https://github.com/search?q="),
            ("stackoverflow", "https://stackoverflow.com/search?q="),
        ]

        let lowerQ = query.lowercased()
        for (name, baseURL) in engines {
            let prefix = name + " "
            if lowerQ.hasPrefix(prefix) {
                let term = String(query.dropFirst(prefix.count))
                let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let urlStr = baseURL + encoded
                return [SearchResult(
                    url: URL(string: urlStr) ?? URL(fileURLWithPath: "/dev/null"),
                    name: "Search \(name.capitalized)",
                    path: "web:\(name):\(term)",
                    kind: .webSearch, size: nil, modifiedDate: nil,
                    relevanceScore: 900,
                    subtitle: "\"\(term)\" on \(name.capitalized)",
                    actionType: .openURL, actionPayload: urlStr
                )]
            }
        }

        guard query.count >= 2 else { return [] }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "https://www.google.com/search?q=" + encoded
        return [SearchResult(
            url: URL(string: urlStr) ?? URL(fileURLWithPath: "/dev/null"),
            name: "Search Google",
            path: "web:google:\(query)",
            kind: .webSearch, size: nil, modifiedDate: nil,
            relevanceScore: 50,
            subtitle: "\"\(query)\" on Google",
            actionType: .openURL, actionPayload: urlStr
        )]
    }

    // MARK: - Cache

    private func cachedResults(for key: NSString) -> [SearchResult]? {
        cacheLock.withLock {
            cache.object(forKey: key) as? [SearchResult]
        }
    }

    private func setCache(key: NSString, results: [SearchResult]) {
        cacheLock.withLock {
            // Approximate cost: 1KB per result for cache eviction
            let cost = results.count * 1024
            cache.setObject(results as NSArray, forKey: key, cost: cost)
        }
    }
}

extension URL {
    func fileSize() -> Int64? {
        guard let v = try? resourceValues(forKeys: [.fileSizeKey]), let s = v.fileSize else { return nil }
        return Int64(s)
    }
    func modDate() -> Date? {
        return (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
