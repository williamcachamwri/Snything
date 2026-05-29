import Foundation
import os

/// Comprehensive in-memory filename index.
/// Scans ALL of /Users recursively — every file, every folder, no depth limit.
/// ~1-3M entries typical, ~50-150MB RAM, indexes in ~5-15 seconds on SSD.
final class FileIndex: @unchecked Sendable {
    static let shared = FileIndex()

    private var entries: [IndexEntry] = []
    private var isIndexing = false
    private var isReady = false
    private let indexLock = OSAllocatedUnfairLock<Void>(initialState: ())

    /// Only skip true system / cache junk. Everything else gets indexed.
    private let excludedExact: Set<String> = [
        "/System/Volumes", "/Volumes", "/.Spotlight-V100", "/.Trashes",
        "/private/var/db", "/private/var/vm", "/dev", "/net", "/home",
        "/usr", "/bin", "/sbin", "/lib", "/tmp", "/var/tmp",
    ]

    private let excludedPrefixes: Set<String> = [
        "/System/Library",              // system frameworks
        "/Library/Caches",              // global caches
        "/usr/local/Caskroom",          // homebrew cask downloads
        "/usr/local/Cellar",            // homebrew cellar
        "/opt/homebrew",                // Apple Silicon homebrew
    ]

    private let excludedSuffixes: Set<String> = [
        ".git/objects",                 // git object store
        ".git/hooks",
        "node_modules",                 // npm deps
        "vendor/bundle",                // ruby deps
        ".build/checkouts",             // swift PM
        ".build/repositories",
        "__pycache__",                  // python cache
        ".gradle",                      // gradle cache
        ".m2/repository",               // maven cache
        ".npm",                        // npm cache
        "Library/Caches",               // user caches
        "Library/Containers",           // sandbox containers
        "Library/Application Support/Google", // browser data
        "Library/Application Support/Firefox",
        "Library/Application Support/Chrome",
        "Library/Safari",
        "Library/Logs",
    ]

    private init() {}

    struct IndexEntry: Sendable {
        let path: String
        let name: String
        let lowerName: String
        let url: URL
        let isDirectory: Bool
        let size: Int64?
        let modDate: Date?
    }

    // MARK: - Search

    func search(query: String, maxResults: Int) -> [SearchResult] {
        ensureIndexed()

        let lowerQ = query.lowercased()
        var results: [SearchResult] = []
        results.reserveCapacity(maxResults)

        let localEntries: [IndexEntry]
        localEntries = indexLock.withLock { self.entries }

        // If index hasn't finished building yet, return empty.
        // Spotlight mdfind in FastSearchEngine will serve as the fallback.
        // deepScan() was removed because it causes CPU overload / crashes
        // when the user types rapidly while the filesystem is being scanned.
        guard !localEntries.isEmpty else { return [] }

        let qCount = lowerQ.count

        for (idx, entry) in localEntries.enumerated() {
            // Batch cancellation check — only every 1000 items to avoid overhead
            if idx % 1000 == 0, Task.isCancelled { break }

            let name = entry.lowerName
            let nCount = name.count
            guard qCount <= nCount else { continue }

            var score: Double = 0

            if name == lowerQ {
                score = 1000
            } else if name.hasPrefix(lowerQ) {
                score = 500 + (Double(qCount) / Double(nCount)) * 200
            } else if name.contains(lowerQ) {
                score = 300 + (Double(qCount) / Double(nCount)) * 100
            } else {
                // Fast fuzzy: all query chars in order
                let qChars = Array(lowerQ)
                let nChars = Array(name)
                var qi = 0
                var ci = 0
                var matched = 0
                var lastMatchCi = -1
                var consecutive: Double = 0

                while qi < qCount && ci < nCount {
                    if qChars[qi] == nChars[ci] {
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

                guard matched == qCount else { continue }
                let gapPenalty = Double(nCount - qCount) * 0.3
                score = max(10, 100 + consecutive - gapPenalty)
            }

            let kind: SearchResult.ResultKind = entry.isDirectory ? .folder : SearchResult.kind(from: entry.url)
            results.append(SearchResult(
                url: entry.url,
                name: entry.name,
                path: entry.path,
                kind: kind,
                size: entry.size,
                modifiedDate: entry.modDate,
                relevanceScore: score
            ))

            if results.count >= maxResults { break }
        }

        return results
    }

    // MARK: - Indexing

    func ensureIndexed() {
        indexLock.withLock { _ in
            guard !isReady, !isIndexing else { return }
            isIndexing = true
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            self.buildIndex()
        }
    }

    var indexIsReady: Bool {
        indexLock.withLock { self.isReady }
    }

    private func buildIndex() {
        let home = NSHomeDirectory()
        let scopes = [home, "/Users"]

        var newEntries: [IndexEntry] = []
        newEntries.reserveCapacity(1_000_000)

        for scope in scopes {
            guard !Task.isCancelled else { break }
            scanAndIndex(at: scope, into: &newEntries)
        }

        indexLock.withLock { _ in
            self.entries = newEntries
            self.isIndexing = false
            self.isReady = true
        }
    }

    private func scanAndIndex(at root: String, into entries: inout [IndexEntry]) {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: root)

        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [],  // NO skips — index everything including hidden files and inside packages
            errorHandler: nil
        ) else { return }

        for case let url as URL in enumerator {
            if Task.isCancelled { break }

            autoreleasepool {
                let path = url.path
                if shouldSkip(path) {
                    enumerator.skipDescendants()
                    return
                }
                let name = url.lastPathComponent
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                entries.append(IndexEntry(
                    path: path,
                    name: name,
                    lowerName: name.lowercased(),
                    url: url,
                    isDirectory: values?.isDirectory ?? false,
                    size: values?.fileSize.map(Int64.init),
                    modDate: values?.contentModificationDate
                ))
            }
        }
    }

    private func shouldSkip(_ path: String) -> Bool {
        // Exact path match
        for ex in excludedExact {
            if path == ex { return true }
        }
        // Prefix match
        for ex in excludedPrefixes {
            if path.hasPrefix(ex) { return true }
        }
        // Suffix / component match
        for ex in excludedSuffixes {
            if path.contains(ex) { return true }
        }
        return false
    }
}
