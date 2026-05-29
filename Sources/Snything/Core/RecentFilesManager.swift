import Foundation

final class RecentFilesManager {
    static let shared = RecentFilesManager()
    private let key = "snything.recentFilePaths"
    private let maxCount = 20

    private init() {}

    var recentPaths: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set {
            let trimmed = Array(newValue.prefix(maxCount))
            UserDefaults.standard.set(trimmed, forKey: key)
        }
    }

    func recordAccess(url: URL) {
        var paths = recentPaths
        let path = url.path
        paths.removeAll { $0 == path }
        paths.insert(path, at: 0)
        recentPaths = Array(paths.prefix(maxCount))
    }

    func recentResults() -> [SearchResult] {
        let fm = FileManager.default
        return recentPaths.compactMap { path in
            guard fm.fileExists(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path)
            return SearchResult(
                url: url,
                name: url.lastPathComponent,
                path: path,
                kind: SearchResult.kind(from: url),
                size: url.fileSize(),
                modifiedDate: url.modDate(),
                relevanceScore: 0
            )
        }
    }
}
