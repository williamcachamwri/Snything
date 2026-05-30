import Foundation
import SwiftUI
import AppKit

protocol SearchProvider: AnyObject, Sendable {
    var name: String { get }
    func search(query: String, maxResults: Int) async throws -> [SearchResult]
    func cancel()
}

extension SearchProvider {
    func normalizeScore(_ raw: Double, minimum: Double = 0, maximum: Double = 1) -> Double {
        let clamped = Swift.max(minimum, Swift.min(raw, maximum))
        return (clamped - minimum) / (maximum - minimum)
    }
}

final class SearchCoordinator: ObservableObject, @unchecked Sendable {
    @Published var results: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var selectedIndex: Int = 0
    @Published var keyboardFocusedIndex: Int = 0
    @Published var showPreview: Bool = false
    @Published var previewResult: SearchResult? = nil
    @Published var showingRecents: Bool = false
    @Published var showingApplications: Bool = false
    @Published var showingClipboard: Bool = false

    @Published var clipboardItems: [ClipboardItem] = []
    @Published var selectedClipboardIndex: Int = 0
    @Published var clipboardFocusedIndex: Int = 0
    @Published var clipboardPreviewItem: ClipboardItem? = nil

    @Published var deletingResultID: String? = nil

    private let engine = FastSearchEngine.shared
    private let clipboard = ClipboardManager.shared
    private var activeTask: Task<Void, Never>?
    private let fm = FileManager.default
    private var fsObserver: NSObjectProtocol?

    init() {
        fsObserver = NotificationCenter.default.addObserver(
            forName: .fileSystemChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleFileSystemChanged()
        }
    }

    deinit {
        if let observer = fsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func handleFileSystemChanged() {
        guard !showingClipboard else { return }

        // Prune deleted files from current results
        let validResults = results.filter { fm.fileExists(atPath: $0.path) }
        if validResults.count != results.count {
            withAnimation(.easeOut(duration: 0.15)) {
                self.results = validResults
                self.selectedIndex = min(self.selectedIndex, max(0, validResults.count - 1))
                self.keyboardFocusedIndex = self.selectedIndex
                if let preview = self.previewResult, !self.fm.fileExists(atPath: preview.path) {
                    self.showPreview = false
                    self.previewResult = nil
                }
            }
        }

        // If showing recents, refresh them
        if showingRecents {
            withAnimation(.easeOut(duration: 0.15)) {
                self.results = RecentFilesManager.shared.recentResults()
                self.selectedIndex = min(self.selectedIndex, max(0, self.results.count - 1))
                self.keyboardFocusedIndex = self.selectedIndex
            }
        }

        // If showing applications, refresh to catch deleted apps
        if showingApplications {
            self.engine.invalidateAppCache()
            self.performSearch(query: "")
        }
    }

    func showRecents() {
        let recents = RecentFilesManager.shared.recentResults()
        let newPaths = recents.map(\.path)
        let currentPaths = results.map(\.path)
        guard newPaths != currentPaths else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            results = recents
            showingRecents = true
            showingApplications = false
            showingClipboard = false
            selectedIndex = 0
            keyboardFocusedIndex = 0
            isSearching = false
            showPreview = false
            previewResult = nil
        }
    }

    func showApplications() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            showingApplications = true
            showingRecents = false
            showingClipboard = false
            selectedIndex = 0
            keyboardFocusedIndex = 0
            isSearching = false
            showPreview = false
            previewResult = nil
            results = []
        }
    }

    func showClipboardHistory() {
        // Always refresh items and switch to clipboard mode
        let items = clipboard.items
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            clipboardItems = items
            showingClipboard = true
            showingRecents = false
            showingApplications = false
            selectedClipboardIndex = 0
            clipboardFocusedIndex = 0
            isSearching = false
            showPreview = false
            previewResult = nil
            clipboardPreviewItem = nil
            results = []
        }
    }

    func toggleClipboardMode() {
        if showingClipboard {
            showRecents()
        } else {
            showClipboardHistory()
        }
    }

    func performSearch(query: String) {
        activeTask?.cancel()
        engine.cancel()

        if showingApplications {
            // Always search in Applications mode (even empty query shows all apps)
            showingClipboard = false
            showingRecents = false
            isSearching = true
            selectedIndex = 0
            keyboardFocusedIndex = 0
            showPreview = false
            previewResult = nil

            let maxResults = SettingsManager.shared.maxResultsInt
            activeTask = Task { [weak self] in
                guard let self else { return }

                try? await Task.sleep(nanoseconds: 80_000_000)
                guard !Task.isCancelled else { return }

                self.engine.searchApplications(query: query, maxResults: maxResults) { batch in
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        self.results = batch
                        self.isSearching = false
                    }
                }
            }
            return
        }

        guard query.count >= 1 else {
            showRecents()
            return
        }

        showingClipboard = false
        showingRecents = false
        isSearching = true
        selectedIndex = 0
        keyboardFocusedIndex = 0
        showPreview = false
        previewResult = nil

        let maxResults = SettingsManager.shared.maxResultsInt

        activeTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }

            self.engine.search(query: query, maxResults: maxResults) { batch in
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    self.results = batch
                    self.isSearching = false
                }
            }
        }
    }

    func cancel() {
        activeTask?.cancel()
        engine.cancel()
        isSearching = false
    }

    func selectNext() {
        if showingClipboard {
            guard !clipboardItems.isEmpty else { return }
            selectedClipboardIndex = (selectedClipboardIndex + 1) % clipboardItems.count
            clipboardFocusedIndex = selectedClipboardIndex
            updateClipboardPreview()
        } else {
            guard !results.isEmpty else { return }
            selectedIndex = (selectedIndex + 1) % results.count
            keyboardFocusedIndex = selectedIndex
            updatePreview()
        }
    }

    func selectPrevious() {
        if showingClipboard {
            guard !clipboardItems.isEmpty else { return }
            selectedClipboardIndex = (selectedClipboardIndex - 1 + clipboardItems.count) % clipboardItems.count
            clipboardFocusedIndex = selectedClipboardIndex
            updateClipboardPreview()
        } else {
            guard !results.isEmpty else { return }
            selectedIndex = (selectedIndex - 1 + results.count) % results.count
            keyboardFocusedIndex = selectedIndex
            updatePreview()
        }
    }

    func openSelected() {
        if showingClipboard {
            guard clipboardItems.indices.contains(selectedClipboardIndex) else { return }
            let item = clipboardItems[selectedClipboardIndex]
            clipboard.pasteToClipboard(item)
            NotificationCenter.default.post(name: .snythingHideWindow, object: nil)
        } else {
            guard results.indices.contains(selectedIndex) else { return }
            let result = results[selectedIndex]
            NSWorkspace.shared.open(result.url)
            NotificationCenter.default.post(name: .snythingHideWindow, object: nil)
        }
    }

    func revealSelected() {
        guard !showingClipboard, results.indices.contains(selectedIndex) else { return }
        let result = results[selectedIndex]
        NSWorkspace.shared.selectFile(result.url.path, inFileViewerRootedAtPath: "")
    }

    func deleteSelectedClipboardItem() {
        guard showingClipboard, clipboardItems.indices.contains(selectedClipboardIndex) else { return }
        let item = clipboardItems[selectedClipboardIndex]
        clipboard.deleteItem(item)
        clipboardItems = clipboard.items
        if selectedClipboardIndex >= clipboardItems.count {
            selectedClipboardIndex = max(0, clipboardItems.count - 1)
        }
        clipboardFocusedIndex = selectedClipboardIndex
    }

    func deleteSelectedFile() {
        guard !showingClipboard, results.indices.contains(selectedIndex) else { return }
        let result = results[selectedIndex]

        deletingResultID = result.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.deletingResultID = nil
                self.results.removeAll { $0.id == result.id }
                self.selectedIndex = min(self.selectedIndex, max(0, self.results.count - 1))
                self.keyboardFocusedIndex = self.selectedIndex
                if self.previewResult?.id == result.id {
                    self.showPreview = false
                    self.previewResult = nil
                }
            }

            // Actually move to trash
            do {
                try FileManager.default.trashItem(at: result.url, resultingItemURL: nil)
            } catch {
                print("[SearchCoordinator] failed to trash \(result.path): \(error)")
            }
        }
    }

    func togglePreview() {
        if showingClipboard {
            guard clipboardItems.indices.contains(selectedClipboardIndex) else { return }
            let item = clipboardItems[selectedClipboardIndex]
            if showPreview && clipboardPreviewItem?.id == item.id {
                withAnimation(.easeOut(duration: 0.15)) {
                    showPreview = false
                    clipboardPreviewItem = nil
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    showPreview = true
                    clipboardPreviewItem = item
                }
            }
        } else {
            guard results.indices.contains(selectedIndex) else { return }
            let result = results[selectedIndex]
            if showPreview && previewResult?.id == result.id {
                withAnimation(.easeOut(duration: 0.15)) {
                    showPreview = false
                    previewResult = nil
                }
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    showPreview = true
                    previewResult = result
                }
            }
        }
    }

    private func updatePreview() {
        let autoPreview = SettingsManager.shared.showPreviewOnSelect
        guard (showPreview || autoPreview), results.indices.contains(selectedIndex) else { return }
        if autoPreview {
            showPreview = true
        }
        previewResult = results[selectedIndex]
    }

    private func updateClipboardPreview() {
        let autoPreview = SettingsManager.shared.showPreviewOnSelect
        guard (showPreview || autoPreview), clipboardItems.indices.contains(selectedClipboardIndex) else { return }
        if autoPreview {
            showPreview = true
        }
        clipboardPreviewItem = clipboardItems[selectedClipboardIndex]
    }
}
