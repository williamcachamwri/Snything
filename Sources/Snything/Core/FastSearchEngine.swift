import Foundation
import AppKit

final class FastSearchEngine: @unchecked Sendable {
    static let shared = FastSearchEngine()

    private var currentTask: Task<Void, Never>?
    private var mdfindProcess: Process?
    private let processLock = NSLock()

    private let cache = NSCache<NSString, NSArray>()
    private let cacheLock = NSLock()

    private let excludedPaths: Set<String> = [
        "/System/Volumes",
        "/Volumes",
        "/.Spotlight-V100",
        "/.Trashes",
        "/private/var/db",
        "/private/var/vm",
        "/dev",
        "/net",
        "/home",
        "/usr",
        "/bin",
        "/sbin",
        "/lib"
    ]

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 5 * 1024 * 1024
    }

    func search(query: String, maxResults: Int = 200, onBatch: @escaping @Sendable ([SearchResult]) -> Void) {
        currentTask?.cancel()
        cancel()

        let task = Task {
            let cacheKey = "\(query)_\(maxResults)" as NSString
            if let cached = self.cachedResults(for: cacheKey) {
                await MainActor.run {
                    onBatch(cached)
                }
                return
            }

            let q = query.trimmingCharacters(in: .whitespaces)
            guard !q.isEmpty else {
                await MainActor.run { onBatch([]) }
                return
            }

            let safeQuery = q.replacingOccurrences(of: "\"", with: "")

            async let spotlightResults = self.runMdfind(query: safeQuery, maxResults: maxResults)
            async let fsResults = self.runFileSystemSearch(query: safeQuery, maxResults: maxResults / 2)

            let spot = await spotlightResults
            let fs = await fsResults

            var dict: [URL: SearchResult] = [:]
            for r in spot { dict[r.url] = r }
            for r in fs { dict[r.url] = r }

            let scored = dict.values.map { r -> SearchResult in
                let lowerName = r.name.lowercased()
                let lowerQ = q.lowercased()
                var score = r.relevanceScore
                if lowerName == lowerQ { score += 20 }
                else if lowerName.hasPrefix(lowerQ) { score += 10 }
                else if lowerName.contains(lowerQ) { score += 4 }
                if r.path.lowercased().contains(lowerQ) { score += 1 }
                if r.kind == .application { score += 3 }
                if r.kind == .folder { score += 1 }
                return SearchResult(
                    url: r.url, name: r.name, path: r.path,
                    kind: r.kind, size: r.size, modifiedDate: r.modifiedDate,
                    relevanceScore: score
                )
            }

            let sorted = Array(scored.sorted { $0.relevanceScore > $1.relevanceScore }.prefix(maxResults))
            self.setCache(key: cacheKey, results: sorted)

            await MainActor.run {
                onBatch(sorted)
            }
        }
        currentTask = task
    }

    func cancel() {
        currentTask?.cancel()
        processLock.lock()
        mdfindProcess?.terminate()
        mdfindProcess = nil
        processLock.unlock()
    }

    // MARK: - mdfind

    private func runMdfind(query: String, maxResults: Int) async -> [SearchResult] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        let pred = "kMDItemDisplayName == '*\(query)*'cd || kMDItemFSName == '*\(query)*'cd"
        process.arguments = [pred, "-onlyin", NSHomeDirectory()]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        processLock.lock()
        mdfindProcess = process
        processLock.unlock()

        defer {
            processLock.lock()
            if mdfindProcess === process { mdfindProcess = nil }
            processLock.unlock()
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

    // MARK: - FileSystem

    private func runFileSystemSearch(query: String, maxResults: Int) async -> [SearchResult] {
        let lowerQ = query.lowercased()
        let showHidden = SettingsManager.shared.showHiddenFiles
        var targets = SettingsManager.shared.searchScopes
        // Always include home + common user dirs if not already present
        let home = NSHomeDirectory()
        let common = [home, "/Applications", "/System/Applications", "/Users"]
        for c in common where !targets.contains(c) {
            targets.append(c)
        }

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
        if !showHidden {
            options.insert(.skipsHiddenFiles)
        }
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

    private func shouldSkipPath(_ path: String) -> Bool {
        for excluded in excludedPaths {
            if path.hasPrefix(excluded) { return true }
        }
        return false
    }

    // MARK: - Cache

    private func cachedResults(for key: NSString) -> [SearchResult]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache.object(forKey: key) as? [SearchResult]
    }

    private func setCache(key: NSString, results: [SearchResult]) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.setObject(results as NSArray, forKey: key)
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
