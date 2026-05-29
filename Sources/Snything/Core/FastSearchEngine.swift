import Foundation
import AppKit
import os

/// Lightweight unfair lock wrapper safe for concurrent use.
/// Replaces NSLock to avoid Swift concurrency warnings in async contexts.
final class UnfairLock {
    private let _lock: os_unfair_lock_t

    init() {
        _lock = .allocate(capacity: 1)
        _lock.initialize(to: os_unfair_lock())
    }

    deinit {
        _lock.deinitialize(count: 1)
        _lock.deallocate()
    }

    @discardableResult
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(_lock)
        defer { os_unfair_lock_unlock(_lock) }
        return try body()
    }
}

/// Ultra-fast parallel search engine using Spotlight (mdfind) as the primary source.
/// Phase 1 (mdfind name) and Phase 2 (mdfind content) run in parallel via TaskGroup.
/// App cache fuzzy runs concurrently. Results are merged, deduplicated, and ranked.
final class FastSearchEngine: @unchecked Sendable {
    static let shared = FastSearchEngine()

    private var currentTask: Task<Void, Never>?
    private var activeProcesses = Set<Process>()
    private let processLock = UnfairLock()

    private let cache = NSCache<NSString, NSArray>()
    private let cacheLock = UnfairLock()

    private var appCache: [SearchResult] = []
    private var appCacheLoaded = false
    private let appCacheLock = UnfairLock()

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 5 * 1024 * 1024
    }

    // MARK: - Entry Point

    func search(query: String, maxResults: Int = 500, onBatch: @escaping @Sendable ([SearchResult]) -> Void) {
        currentTask?.cancel()
        cancelProcesses()

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

            // Phase 1: Spotlight name search (async)
            // Phase 2: Cached apps fuzzy (async) 
            // Phase 3: Spotlight content search (async, only if query >= 8 chars)
            // All three run in parallel via TaskGroup
            let startTime = Date()
            var allResults: [SearchResult] = []

            await withTaskGroup(of: [SearchResult].self) { group in
                // Thread 1: Spotlight name search — PRIMARY, covers EVERY file on Mac
                group.addTask {
                    await self.runMdfindName(query: q, maxResults: maxResults)
                }

                // Thread 2: App cache fuzzy — covers display names Spotlight might miss
                group.addTask {
                    await self.scanApplications(query: q, maxResults: 100)
                }

                // Thread 3: Content search — only for long queries, heavily limited
                if q.count >= 8 {
                    group.addTask {
                        await self.runMdfindContent(query: q, maxResults: 5)
                    }
                }

                for await results in group {
                    if Task.isCancelled { break }
                    allResults.append(contentsOf: results)
                }
            }

            guard !Task.isCancelled else {
                await MainActor.run { onBatch([]) }
                return
            }

            // Deduplicate by path + sort by relevance
            var seen = Set<String>()
            var unique: [SearchResult] = []
            unique.reserveCapacity(min(allResults.count, maxResults))
            for r in allResults.sorted(by: { $0.relevanceScore > $1.relevanceScore }) {
                if seen.insert(r.id).inserted {
                    unique.append(r)
                    if unique.count >= maxResults { break }
                }
            }

            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0.5 {
                print("[Search] slow query '\(q)' took \(String(format: "%.2f", elapsed))s, \(unique.count) results")
            }

            let finalResults = unique
            self.setCache(key: cacheKey, results: finalResults)
            await MainActor.run { onBatch(finalResults) }
        }
        currentTask = task
    }

    func cancel() {
        currentTask?.cancel()
        cancelProcesses()
    }

    // MARK: - Spotlight Name Search (primary, most important)

    private func runMdfindName(query: String, maxResults: Int) async -> [SearchResult] {
        let escaped = escapeForPredicate(query)
        let pred = "kMDItemDisplayName == '*\(escaped)*'cd || kMDItemFSName == '*\(escaped)*'cd"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [pred]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        processLock.withLock {
            activeProcesses.insert(process)
        }
        defer {
            processLock.withLock {
                activeProcesses.remove(process)
            }
        }

        do {
            try process.run()
        } catch { return [] }

        // Read with timeout — if cancelled, kill the process immediately
        let data: Data
        do {
            data = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
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
                url: url, name: url.lastPathComponent, path: url.path,
                kind: SearchResult.kind(from: url),
                size: url.fileSize(), modifiedDate: url.modDate(),
                relevanceScore: 10.0
            ))
        }
        return results
    }

    // MARK: - Spotlight Content Search (limited, parallel)

    private func runMdfindContent(query: String, maxResults: Int) async -> [SearchResult] {
        let escaped = escapeForPredicate(query)
        let pred = "kMDItemTextContent == '*\(escaped)*'cd"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [pred]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        processLock.withLock {
            activeProcesses.insert(process)
        }
        defer {
            processLock.withLock {
                activeProcesses.remove(process)
            }
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
        let paths = rawPaths.prefix(maxResults)
        for path in paths {
            guard !Task.isCancelled else { break }
            let url = URL(fileURLWithPath: String(path))
            guard fm.fileExists(atPath: url.path) else { continue }
            results.append(SearchResult(
                url: url, name: url.lastPathComponent, path: url.path,
                kind: SearchResult.kind(from: url),
                size: url.fileSize(), modifiedDate: url.modDate(),
                relevanceScore: 0.5,
                subtitle: "Content match"
            ))
        }
        return results
    }

    // MARK: - Predicate Escaping

    private func escapeForPredicate(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    // MARK: - Applications Search

    func searchApplications(query: String, maxResults: Int = 200, onBatch: @escaping @Sendable ([SearchResult]) -> Void) {
        currentTask?.cancel()
        cancelProcesses()

        let task = Task {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard q.count <= 100 else {
                await MainActor.run { onBatch([]) }
                return
            }

            let qLower = q.lowercased()
            var allResults: [SearchResult] = []

            if q.isEmpty {
                // Empty query: return all apps from cache (alphabetical)
                allResults = await self.allApplications(maxResults: maxResults)
            } else {
                // Phase 1: mdfind for .app bundles by name
                let mdfindResults = await self.runMdfindApps(query: q, maxResults: maxResults)
                allResults.append(contentsOf: mdfindResults)

                // Phase 2: app cache fuzzy for display names
                let fuzzyResults = await self.scanApplications(query: qLower, maxResults: maxResults)
                allResults.append(contentsOf: fuzzyResults)
            }

            guard !Task.isCancelled else {
                await MainActor.run { onBatch([]) }
                return
            }

            // Deduplicate by path + sort by relevance
            var seen = Set<String>()
            var unique: [SearchResult] = []
            unique.reserveCapacity(min(allResults.count, maxResults))
            for r in allResults.sorted(by: { $0.relevanceScore > $1.relevanceScore }) {
                if seen.insert(r.id).inserted {
                    unique.append(r)
                    if unique.count >= maxResults { break }
                }
            }

            let finalResults = unique
            await MainActor.run { onBatch(finalResults) }
        }
        currentTask = task
    }

    private func allApplications(maxResults: Int) async -> [SearchResult] {
        ensureAppCache()
        let cached = appCacheLock.withLock { appCache }

        return cached
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .prefix(maxResults)
            .map { app in
                SearchResult(
                    url: app.url, name: app.name, path: app.path,
                    kind: .application, size: nil, modifiedDate: nil,
                    relevanceScore: 1.0
                )
            }
    }

    private func runMdfindApps(query: String, maxResults: Int) async -> [SearchResult] {
        let escaped = escapeForPredicate(query)
        let pred = "kMDItemContentType == 'com.apple.application-bundle' && (kMDItemDisplayName == '*\(escaped)*'cd || kMDItemFSName == '*\(escaped)*'cd)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [pred]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        processLock.withLock {
            activeProcesses.insert(process)
        }
        defer {
            processLock.withLock {
                activeProcesses.remove(process)
            }
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
            let name = appDisplayName(for: url)
            results.append(SearchResult(
                url: url, name: name, path: url.path,
                kind: .application, size: nil, modifiedDate: nil,
                relevanceScore: 10.0
            ))
        }
        return results
    }

    // MARK: - Applications

    private func ensureAppCache() {
        appCacheLock.withLock {
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
    }

    private func scanApplications(query: String, maxResults: Int) async -> [SearchResult] {
        ensureAppCache()
        let cached = appCacheLock.withLock { appCache }

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

    // MARK: - Process Control

    private func cancelProcesses() {
        let procs = processLock.withLock {
            let p = Array(activeProcesses)
            activeProcesses.removeAll()
            return p
        }
        for proc in procs {
            proc.terminate()
        }
    }

    // MARK: - Cache

    private func cachedResults(for key: NSString) -> [SearchResult]? {
        cacheLock.withLock {
            cache.object(forKey: key) as? [SearchResult]
        }
    }

    private func setCache(key: NSString, results: [SearchResult]) {
        cacheLock.withLock {
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
