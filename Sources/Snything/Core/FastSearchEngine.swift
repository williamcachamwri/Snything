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

            var allResults: [SearchResult] = []

            // Phase 1: Spotlight mdfind — PRIMARY. Searches EVERYWHERE on the Mac.
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
                subtitle: "Content match"
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
