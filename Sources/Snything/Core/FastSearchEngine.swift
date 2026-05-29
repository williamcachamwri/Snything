import Foundation
import AppKit

/// Ultra-fast parallel search engine. All phases run concurrently via Swift TaskGroup.
/// Results stream back in real-time as each phase completes — no waiting for the slowest.
///
/// Phases (all parallel):
///   1. mdfind name      — Spotlight name index, covers every file on Mac
///   2. mdfind content   — Spotlight full-text index (query >= 4 chars)
///   3. mdfind metadata  — Spotlight tags, comments, authors, keywords
///   4. fileSystemScan   — Direct recursive scan of ~/Desktop, ~/Downloads,
///                         ~/Documents, and home dir (shallow) for exact/prefix match
///   5. app cache fuzzy  — Display-name fuzzy for apps Spotlight might miss
///
/// Deduplication, ranking, and maxResults capping happen in real-time as batches arrive.
final class FastSearchEngine: @unchecked Sendable {
    static let shared = FastSearchEngine()

    private var currentTask: Task<Void, Never>?
    private var activeProcesses = Set<Process>()
    private let processLock = NSLock()

    private let cache = NSCache<NSString, NSArray>()
    private let cacheLock = NSLock()

    private var appCache: [SearchResult] = []
    private var appCacheLoaded = false
    private let appCacheLock = NSLock()

    /// Directories scanned by the file-system fallback (shallow, fast)
    private let scanDirs: [URL] = [
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop"),
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads"),
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents"),
        URL(fileURLWithPath: NSHomeDirectory()),
    ]

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 5 * 1024 * 1024
    }

    // MARK: - Public API

    /// Start a new search. Cancels any previous search instantly.
    ///
    /// `onBatch` is called **multiple times** as each parallel phase finishes,
    /// so the UI updates progressively instead of freezing until everything is done.
    func search(query: String, maxResults: Int = 1000, onBatch: @escaping @Sendable ([SearchResult]) -> Void) {
        currentTask?.cancel()
        cancelProcesses()

        let task = Task {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard !q.isEmpty, q.count <= 100 else {
                await MainActor.run { onBatch([]) }
                return
            }

            // Cache key — only full queries benefit, not partial typing
            let cacheKey = "\(q)_\(maxResults)" as NSString
            if let cached = self.cachedResults(for: cacheKey) {
                await MainActor.run { onBatch(cached) }
                return
            }

            let startTime = Date()
            let qLower = q.lowercased()

            // Shared accumulator — each phase appends, main thread deduplicates
            let accumulator = SearchAccumulator(maxResults: maxResults)

            await withTaskGroup(of: Void.self) { group in
                // Phase 1 — Spotlight name (the heavyweight, usually fastest)
                group.addTask {
                    let results = await self.runMdfindName(query: q, maxResults: maxResults * 2)
                    await accumulator.append(results, source: "name")
                    let batch = await accumulator.currentUniqueResults()
                    if !Task.isCancelled, !batch.isEmpty {
                        await MainActor.run { onBatch(batch) }
                    }
                }

                // Phase 2 — Spotlight content (full-text, only meaningful queries)
                if q.count >= 4 {
                    group.addTask {
                        let results = await self.runMdfindContent(query: q, maxResults: 30)
                        await accumulator.append(results, source: "content")
                        let batch = await accumulator.currentUniqueResults()
                        if !Task.isCancelled, !batch.isEmpty {
                            await MainActor.run { onBatch(batch) }
                        }
                    }
                }

                // Phase 3 — Spotlight metadata (tags, comments, authors)
                group.addTask {
                    let results = await self.runMdfindMetadata(query: q, maxResults: 30)
                    await accumulator.append(results, source: "metadata")
                    let batch = await accumulator.currentUniqueResults()
                    if !Task.isCancelled, !batch.isEmpty {
                        await MainActor.run { onBatch(batch) }
                    }
                }

                // Phase 4 — File-system shallow scan (instant for exact/prefix match)
                group.addTask {
                    let results = await self.scanFileSystem(query: qLower, maxResults: 200)
                    await accumulator.append(results, source: "fs")
                    let batch = await accumulator.currentUniqueResults()
                    if !Task.isCancelled, !batch.isEmpty {
                        await MainActor.run { onBatch(batch) }
                    }
                }

                // Phase 5 — App cache fuzzy (always fast)
                group.addTask {
                    let results = await self.scanApplications(query: qLower, maxResults: 100)
                    await accumulator.append(results, source: "app")
                    let batch = await accumulator.currentUniqueResults()
                    if !Task.isCancelled, !batch.isEmpty {
                        await MainActor.run { onBatch(batch) }
                    }
                }
            }

            guard !Task.isCancelled else {
                await MainActor.run { onBatch([]) }
                return
            }

            // Final ranked & deduplicated list
            let final = await accumulator.currentUniqueResults()
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0.3 {
                print("[Search] '\(q)' took \(String(format: "%.3f", elapsed))s → \(final.count) results")
            }
            self.setCache(key: cacheKey, results: final)
            await MainActor.run { onBatch(final) }
        }
        currentTask = task
    }

    func cancel() {
        currentTask?.cancel()
        cancelProcesses()
    }

    // MARK: - Phase 1: Spotlight Name

    private func runMdfindName(query: String, maxResults: Int) async -> [SearchResult] {
        let escaped = escapeForPredicate(query)
        let pred = "kMDItemDisplayName == '*\(escaped)*'cd || kMDItemFSName == '*\(escaped)*'cd"
        return await runMdfind(predicate: pred, maxResults: maxResults, scoreBase: 10.0)
    }

    // MARK: - Phase 2: Spotlight Content

    private func runMdfindContent(query: String, maxResults: Int) async -> [SearchResult] {
        let escaped = escapeForPredicate(query)
        let pred = "kMDItemTextContent == '*\(escaped)*'cd"
        return await runMdfind(predicate: pred, maxResults: maxResults, scoreBase: 0.5, subtitle: "Content match")
    }

    // MARK: - Phase 3: Spotlight Metadata (tags, comments, authors, keywords)

    private func runMdfindMetadata(query: String, maxResults: Int) async -> [SearchResult] {
        let escaped = escapeForPredicate(query)
        let pred = "kMDItemUserTags == '*\(escaped)*'cd || " +
                   "kMDItemFinderComment == '*\(escaped)*'cd || " +
                   "kMDItemAuthors == '*\(escaped)*'cd || " +
                   "kMDItemKeywords == '*\(escaped)*'cd || " +
                   "kMDItemTitle == '*\(escaped)*'cd"
        return await runMdfind(predicate: pred, maxResults: maxResults, scoreBase: 0.7, subtitle: "Tag / Comment")
    }

    // MARK: - Generic mdfind runner

    private func runMdfind(
        predicate: String,
        maxResults: Int,
        scoreBase: Double,
        subtitle: String? = nil
    ) async -> [SearchResult] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [predicate]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        processLock.lock()
        activeProcesses.insert(process)
        processLock.unlock()
        defer {
            processLock.lock()
            activeProcesses.remove(process)
            processLock.unlock()
        }

        do { try process.run() } catch { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard !Task.isCancelled else { return [] }

        let rawPaths = String(data: data, encoding: .utf8)?
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty } ?? []

        let fm = FileManager.default
        var results: [SearchResult] = []
        results.reserveCapacity(min(rawPaths.count, maxResults))
        let paths = rawPaths.prefix(maxResults)

        for path in paths {
            guard !Task.isCancelled else { break }
            let url = URL(fileURLWithPath: String(path))
            guard fm.fileExists(atPath: url.path) else { continue }
            results.append(SearchResult(
                url: url,
                name: url.lastPathComponent,
                path: url.path,
                kind: SearchResult.kind(from: url),
                size: url.fileSize(),
                modifiedDate: url.modDate(),
                relevanceScore: scoreBase,
                subtitle: subtitle ?? ""
            ))
        }
        return results
    }

    // MARK: - Phase 4: File-system shallow scan

    /// Scans Desktop, Downloads, Documents, and home dir (shallow).
    /// This catches files Spotlight hasn't indexed yet, or exact/prefix matches
    /// that deserve a boost.
    private func scanFileSystem(query: String, maxResults: Int) async -> [SearchResult] {
        let fm = FileManager.default
        var results: [SearchResult] = []

        for dir in scanDirs {
            guard !Task.isCancelled else { break }
            guard let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            ) else { continue }

            for url in contents {
                guard !Task.isCancelled else { break }
                let name = url.lastPathComponent.lowercased()

                // Exact match gets huge boost
                var score: Double = 0
                if name == query {
                    score = 1000
                } else if name.hasPrefix(query) {
                    score = 500 + (Double(query.count) / Double(name.count)) * 200
                } else if name.contains(query) {
                    score = 300 + (Double(query.count) / Double(name.count)) * 100
                } else {
                    // Fuzzy fallback for file system
                    let fuzzy = FuzzyMatcher.score(query: query, candidate: name)
                    if fuzzy > 0 { score = fuzzy }
                }

                guard score > 0 else { continue }

                var subtitle = dir.lastPathComponent
                if dir.path == NSHomeDirectory() {
                    subtitle = "Home"
                }

                results.append(SearchResult(
                    url: url,
                    name: url.lastPathComponent,
                    path: url.path,
                    kind: SearchResult.kind(from: url),
                    size: url.fileSize(),
                    modifiedDate: url.modDate(),
                    relevanceScore: score + 5, // FS results get slight priority bump
                    subtitle: subtitle
                ))

                if results.count >= maxResults { break }
            }
        }
        return results
    }

    // MARK: - Phase 5: Application cache fuzzy

    private func ensureAppCache() {
        appCacheLock.lock()
        defer { appCacheLock.unlock() }
        guard !appCacheLoaded else { return }

        let dirs = ["/Applications", "/System/Applications", "\(NSHomeDirectory())/Applications"]
        let fm = FileManager.default
        var apps: [SearchResult] = []
        for dir in dirs {
            guard let urls = try? fm.contentsOfDirectory(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: nil
            ) else { continue }
            for url in urls where url.pathExtension == "app" {
                let name = appDisplayName(for: url)
                apps.append(SearchResult(
                    url: url, name: name, path: url.path,
                    kind: .application, size: nil, modifiedDate: nil,
                    relevanceScore: 0,
                    subtitle: url.deletingLastPathComponent().path
                ))
            }
        }
        appCache = apps
        appCacheLoaded = true
    }

    private func scanApplications(query: String, maxResults: Int) async -> [SearchResult] {
        ensureAppCache()
        var cached: [SearchResult] = []
        appCacheLock.lock()
        cached = appCache
        appCacheLock.unlock()

        var results: [SearchResult] = []
        for app in cached {
            guard !Task.isCancelled else { break }
            let score = FuzzyMatcher.score(query: query, candidate: app.name.lowercased())
            guard score > 0 else { continue }
            results.append(SearchResult(
                url: app.url, name: app.name, path: app.path,
                kind: .application, size: nil, modifiedDate: nil,
                relevanceScore: score + 5,
                subtitle: app.subtitle
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

    // MARK: - Helpers

    private func escapeForPredicate(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "'", with: "\\'")
    }

    private func cancelProcesses() {
        processLock.lock()
        let procs = Array(activeProcesses)
        activeProcesses.removeAll()
        processLock.unlock()
        for proc in procs { proc.terminate() }
    }

    private func cachedResults(for key: NSString) -> [SearchResult]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache.object(forKey: key) as? [SearchResult]
    }

    private func setCache(key: NSString, results: [SearchResult]) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.setObject(results as NSArray, forKey: key, cost: results.count * 1024)
    }
}

// MARK: - SearchAccumulator (actor-isolated dedup + ranking)

actor SearchAccumulator {
    private let maxResults: Int
    private var all: [SearchResult] = []
    private var seen = Set<String>()

    init(maxResults: Int) {
        self.maxResults = maxResults
    }

    func append(_ results: [SearchResult], source: String) {
        for r in results {
            if seen.insert(r.id).inserted {
                all.append(r)
            }
        }
    }

    func currentUniqueResults() -> [SearchResult] {
        let sorted = all.sorted { $0.relevanceScore > $1.relevanceScore }
        if sorted.count > maxResults {
            return Array(sorted.prefix(maxResults))
        }
        return sorted
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
