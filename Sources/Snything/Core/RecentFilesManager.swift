import Foundation

final class RecentFilesManager {
    static let shared = RecentFilesManager()

    private init() {}

    private var maxCount: Int {
        SettingsManager.shared.maxRecentsInt
    }

    func recentResults() -> [SearchResult] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let dirs = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Pictures"),
        ]

        var results: [SearchResult] = []
        for dir in dirs {
            guard let urls = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for url in urls {
                guard let values = try? url.resourceValues(
                    forKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey]
                ) else { continue }

                let modDate = values.contentModificationDate
                let size = values.fileSize.map(Int64.init)
                let isDir = values.isDirectory ?? false
                let kind: SearchResult.ResultKind = isDir ? .folder : SearchResult.kind(from: url)

                results.append(SearchResult(
                    url: url,
                    name: url.lastPathComponent,
                    path: url.path,
                    kind: kind,
                    size: size,
                    modifiedDate: modDate,
                    relevanceScore: 0
                ))
            }
        }

        return results
            .sorted { ($0.modifiedDate ?? .distantPast) > ($1.modifiedDate ?? .distantPast) }
            .prefix(maxCount)
            .map { $0 }
    }
}
