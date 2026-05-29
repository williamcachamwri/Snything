import Foundation
import AppKit

/// Manages security-scoped bookmarks for folder access.
/// On first launch, prompts the user to select protected folders via NSOpenPanel.
/// Bookmarks are persisted in UserDefaults and restored on subsequent launches.
final class BookmarkManager {
    static let shared = BookmarkManager()
    private let bookmarksKey = "snything.securityBookmarks.v2"
    private var activeResources: [URL] = []

    private init() {}

    var hasBookmark: Bool {
        guard let data = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data], !data.isEmpty else {
            return false
        }
        return true
    }

    /// Restores stored bookmarks and starts accessing them. Call on every app launch.
    func restoreAccess() {
        stopAllAccess()
        guard let bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] else { return }

        for data in bookmarks {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if isStale {
                    if let fresh = try? url.bookmarkData(options: .withSecurityScope) {
                        _ = try? replaceBookmark(old: data, with: fresh)
                    }
                }
                if url.startAccessingSecurityScopedResource() {
                    activeResources.append(url)
                }
            } catch {
                print("[BookmarkManager] failed to restore bookmark: \(error)")
            }
        }
    }

    /// Stops accessing all previously started resources.
    func stopAllAccess() {
        for url in activeResources {
            url.stopAccessingSecurityScopedResource()
        }
        activeResources.removeAll()
    }

    /// Presents an NSOpenPanel for the user to select protected folders.
    /// Grants security-scoped bookmarks for each selected folder.
    @MainActor
    func requestAccess() async -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Grant Snything Access to Your Folders"
        panel.message = "Select the folders Snything should be allowed to search. You can also enable Full Disk Access in System Settings for complete access."
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        let result = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())
        guard result == .OK else { return false }

        var bookmarkDataList: [Data] = []
        for url in panel.urls {
            do {
                let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                bookmarkDataList.append(data)
                if url.startAccessingSecurityScopedResource() {
                    activeResources.append(url)
                }
            } catch {
                print("[BookmarkManager] failed to create bookmark: \(error)")
            }
        }

        // Merge with existing bookmarks
        let existing = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []
        let merged = Array(Set(existing + bookmarkDataList))
        UserDefaults.standard.set(merged, forKey: bookmarksKey)
        return !bookmarkDataList.isEmpty
    }

    /// Wrap a synchronous block with security-scoped resource access.
    /// Call this around any FileManager operation that might hit a protected folder.
    func withSecurityAccess<T>(_ operation: () throws -> T) rethrows -> T {
        // Start all known bookmarks
        var started: [URL] = []
        if let bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] {
            for data in bookmarks {
                var isStale = false
                if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    if url.startAccessingSecurityScopedResource() {
                        started.append(url)
                    }
                }
            }
        }
        defer {
            for url in started {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    /// Async version of withSecurityAccess.
    func withSecurityAccess<T>(_ operation: () async throws -> T) async rethrows -> T {
        var started: [URL] = []
        if let bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] {
            for data in bookmarks {
                var isStale = false
                if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    if url.startAccessingSecurityScopedResource() {
                        started.append(url)
                    }
                }
            }
        }
        defer {
            for url in started {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation()
    }

    private func replaceBookmark(old: Data, with fresh: Data) throws -> Bool {
        guard var bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] else {
            return false
        }
        if let index = bookmarks.firstIndex(of: old) {
            bookmarks[index] = fresh
            UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
            return true
        }
        return false
    }
}
