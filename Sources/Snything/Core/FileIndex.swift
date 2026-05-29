import Foundation
import os

/// Ultra-fast in-memory filename index.
/// Loads filenames on first search, then serves queries from RAM without filesystem I/O.
final class FileIndex: @unchecked Sendable {
    static let shared = FileIndex()

    private var entries: [IndexEntry] = []
    private var isIndexing = false
    private let indexLock = OSAllocatedUnfairLock<Void>(initialState: ())

    private let excludedPaths: Set<String> = [
        "/System/Volumes", "/Volumes", "/.Spotlight-V100", "/.Trashes",
        "/private/var/db", "/private/var/vm", "/dev", "/net", "/home",
        "/usr", "/bin", "/sbin", "/lib", "/System/Library", "/Library/Caches"
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

        for entry in localEntries {
            guard !Task.isCancelled else { break }

            let name = entry.lowerName
            var score: Double = 0

            if name == lowerQ {
                score = 1000
            } else if name.hasPrefix(lowerQ) {
                score = 500 + (Double(lowerQ.count) / Double(name.count)) * 200
            } else if name.contains(lowerQ) {
                score = 300 + (Double(lowerQ.count) / Double(name.count)) * 100
            } else {
                // Fast fuzzy: check if all query chars exist in order
                var qi = lowerQ.startIndex
                var ci = name.startIndex
                var matched = 0
                var lastMatch: String.Index?
                var consecutive: Double = 0

                while qi < lowerQ.endIndex && ci < name.endIndex {
                    if lowerQ[qi] == name[ci] {
                        matched += 1
                        if let last = lastMatch {
                            let dist = name.distance(from: last, to: ci)
                            if dist == 1 { consecutive += 15 }
                            else if dist <= 3 { consecutive += 5 }
                        }
                        lastMatch = ci
                        name.formIndex(after: &qi)
                    }
                    name.formIndex(after: &ci)
                }

                guard matched == lowerQ.count else { continue }
                let gapPenalty = Double(name.count - lowerQ.count) * 0.3
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
            guard entries.isEmpty, !isIndexing else { return }
            isIndexing = true
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            self.buildIndex()
        }
    }

    private func buildIndex() {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let scopes = [home, "/Applications", "/System/Applications", "/Users"]

        var newEntries: [IndexEntry] = []
        newEntries.reserveCapacity(200_000)

        for scope in scopes {
            guard !Task.isCancelled else { break }
            scanAndIndex(at: scope, into: &newEntries)
        }

        // Sort by name for consistent ordering
        newEntries.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        indexLock.withLock { _ in
            self.entries = newEntries
            self.isIndexing = false
        }
    }

    private func scanAndIndex(at root: String, into entries: inout [IndexEntry]) {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: root)

        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: nil
        ) else { return }

        for case let url as URL in enumerator {
            if Task.isCancelled { break }
            if entries.count >= 500_000 { break }

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
        for ex in excludedPaths {
            if path.hasPrefix(ex) { return true }
        }
        return false
    }
}
