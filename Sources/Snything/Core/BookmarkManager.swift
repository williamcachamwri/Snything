import Foundation
import AppKit

/// Manages security-scoped bookmarks for folder access.
/// On first launch, prompts the user to select their home directory via NSOpenPanel.
/// The bookmark is persisted in UserDefaults and restored on subsequent launches.
final class BookmarkManager {
    static let shared = BookmarkManager()
    private let bookmarksKey = "snything.securityBookmarks"
    private var activeResources: [URL] = []

    private init() {}

    /// Returns true if we have at least one valid bookmark stored.
    var hasBookmark: Bool {
        guard let data = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data], !data.isEmpty else {
            return false
        }
        return true
    }

    /// Call on app launch. Restores all stored bookmarks and starts accessing them.
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
                    // Refresh stale bookmark
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

    /// Presents an NSOpenPanel so the user can select folders to grant access to.
    /// Call this when `hasBookmark` is false or when permission is denied.
    @MainActor
    func requestAccess() async -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Grant Snything Access to Your Folders"
        panel.message = "Please select your home folder so Snything can search your files without asking again."
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

        UserDefaults.standard.set(bookmarkDataList, forKey: bookmarksKey)
        return !bookmarkDataList.isEmpty
    }

    /// Replaces a stale bookmark in UserDefaults.
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
