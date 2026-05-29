import Foundation
import AppKit
import os

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

    private let excludedPaths: Set<String> = [
        "/System/Volumes", "/Volumes", "/.Spotlight-V100", "/.Trashes",
        "/private/var/db", "/private/var/vm", "/dev", "/net", "/home",
        "/usr", "/bin", "/sbin", "/lib"
    ]

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
            guard !q.isEmpty else {
                await MainActor.run { onBatch([]) }
                return
            }

            let safeQuery = q.replacingOccurrences(of: "\"", with: "")

            // Phase 1: Instant synchronous results (calculator, commands, web)
            var allResults: [SearchResult] = []
            allResults.append(contentsOf: self.evaluateCalculator(query: q))
            allResults.append(contentsOf: self.builtInCommands(query: q))
            allResults.append(contentsOf: self.webSearches(query: q))

            // Phase 2: Parallel async (apps, filesystem, spotlight name)
            async let appResults = self.scanApplications(query: q, maxResults: maxResults)
            async let fsResults = self.runFileSystemSearch(query: safeQuery, maxResults: maxResults / 2)
            async let spotResults = self.runMdfind(query: safeQuery, maxResults: maxResults)

            let apps = await appResults
            let fs = await fsResults
            let spot = await spotResults

            allResults.append(contentsOf: apps)
            allResults.append(contentsOf: fs)
            allResults.append(contentsOf: spot)

            // Phase 3: Content search (sequential after name search, only for longer queries)
            if q.count >= 3 {
                let content = await self.runContentSearch(query: safeQuery, maxResults: 20)
                allResults.append(contentsOf: content)
            }

            // Score everything with fuzzy + source bonuses
            let scored = allResults.map { r in
                var s = FuzzyMatcher.score(query: q, candidate: r.name)
                s += r.relevanceScore
                if r.kind == .application { s += 5 }
                return SearchResult(
                    url: r.url, name: r.name, path: r.path,
                    kind: r.kind, size: r.size, modifiedDate: r.modifiedDate,
                    relevanceScore: s,
                    subtitle: r.subtitle,
                    actionType: r.actionType,
                    actionPayload: r.actionPayload
                )
            }

            // Deduplicate by path/id
            var seen = Set<String>()
            var unique: [SearchResult] = []
            unique.reserveCapacity(scored.count)
            for r in scored {
                if seen.insert(r.id).inserted {
                    unique.append(r)
                }
            }

            let sorted = Array(unique.sorted { $0.relevanceScore > $1.relevanceScore }.prefix(maxResults))
            self.setCache(key: cacheKey, results: sorted)

            await MainActor.run {
                onBatch(sorted)
            }
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

    // MARK: - Spotlight (name)

    private func runMdfind(query: String, maxResults: Int) async -> [SearchResult] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        let pred = "kMDItemDisplayName == '*\(query)*'cd || kMDItemFSName == '*\(query)*'cd"
        process.arguments = [pred, "-onlyin", NSHomeDirectory()]
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
                relevanceScore: 2.0
            ))
        }
        return results
    }

    // MARK: - Content Search

    private func runContentSearch(query: String, maxResults: Int) async -> [SearchResult] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        let pred = "kMDItemTextContent == '*\(query)*'cd"
        process.arguments = [pred, "-onlyin", NSHomeDirectory()]
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
                relevanceScore: 0.5,
                subtitle: "Found in content",
                actionType: .openFile, actionPayload: ""
            ))
        }
        return results
    }

    // MARK: - FileSystem

    private func runFileSystemSearch(query: String, maxResults: Int) async -> [SearchResult] {
        let lowerQ = query.lowercased()
        let showHidden = SettingsManager.shared.showHiddenFiles
        var targets = SettingsManager.shared.searchScopes
        let home = NSHomeDirectory()
        let common = [home, "/Applications", "/System/Applications", "/Users"]
        for c in common where !targets.contains(c) { targets.append(c) }

        return await withTaskGroup(of: [SearchResult].self) { group in
            for target in targets {
                group.addTask {
                    guard !Task.isCancelled else { return [] }
                    return self.shallowScan(at: target, query: lowerQ, maxResults: maxResults, showHidden: showHidden)
                }
            }
            var all: [SearchResult] = []
            for await batch in group {
                all.append(contentsOf: batch)
                if all.count >= maxResults { group.cancelAll() }
            }
            return Array(all.prefix(maxResults))
        }
    }

    private func shallowScan(at root: String, query: String, maxResults: Int, showHidden: Bool) -> [SearchResult] {
        let fm = FileManager.default
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !showHidden { options.insert(.skipsHiddenFiles) }
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: root),
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: options,
            errorHandler: nil
        ) else { return [] }

        var results: [SearchResult] = []
        results.reserveCapacity(maxResults)

        for case let url as URL in enumerator {
            guard !Task.isCancelled else { break }
            if results.count >= maxResults { break }

            autoreleasepool {
                let path = url.path
                if self.shouldSkipPath(path) {
                    enumerator.skipDescendants()
                    return
                }
                let name = url.lastPathComponent.lowercased()
                guard name.contains(query) || path.lowercased().contains(query) else { return }
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                results.append(SearchResult(
                    url: url, name: url.lastPathComponent, path: path,
                    kind: isDir ? .folder : SearchResult.kind(from: url),
                    size: url.fileSize(), modifiedDate: url.modDate(),
                    relevanceScore: name.hasPrefix(query) ? 3.0 : 1.5
                ))
            }
        }
        return results
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

    // MARK: - Calculator

    private func evaluateCalculator(query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let hasDigits = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        let ops = CharacterSet(charactersIn: "+-*/().")
        let hasOp = trimmed.rangeOfCharacter(from: ops) != nil
        guard hasDigits && hasOp else { return [] }

        let letters = CharacterSet.letters
        guard trimmed.rangeOfCharacter(from: letters) == nil else { return [] }

        let expr = NSExpression(format: trimmed)
        guard let value = expr.expressionValue(with: nil, context: nil) as? NSNumber else { return [] }

        let result = value.doubleValue
        let resultStr = abs(result.truncatingRemainder(dividingBy: 1)) < 0.0001
            ? String(Int(result))
            : String(format: "%.4f", result)
                .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)

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

        // Fallback: always offer Google search for any query >= 2 chars
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

    // MARK: - Helpers

    private func shouldSkipPath(_ path: String) -> Bool {
        for excluded in excludedPaths {
            if path.hasPrefix(excluded) { return true }
        }
        return false
    }

    private func cachedResults(for key: NSString) -> [SearchResult]? {
        cacheLock.withLock {
            cache.object(forKey: key) as? [SearchResult]
        }
    }

    private func setCache(key: NSString, results: [SearchResult]) {
        cacheLock.withLock {
            cache.setObject(results as NSArray, forKey: key)
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
