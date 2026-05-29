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
    @Published var showingClipboard: Bool = false

    @Published var clipboardItems: [ClipboardItem] = []
    @Published var selectedClipboardIndex: Int = 0
    @Published var clipboardFocusedIndex: Int = 0

    private let engine = FastSearchEngine.shared
    private let clipboard = ClipboardManager.shared
    private var activeTask: Task<Void, Never>?

    func showClipboardHistory() {
        let items = clipboard.items
        let currentIDs = clipboardItems.map(\.id)
        let newIDs = items.map(\.id)
        guard newIDs != currentIDs else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            clipboardItems = items
            showingClipboard = true
            selectedClipboardIndex = 0
            clipboardFocusedIndex = 0
            isSearching = false
            showPreview = false
            previewResult = nil
            results = []
        }
    }

    func performSearch(query: String) {
        activeTask?.cancel()
        engine.cancel()

        guard query.count >= 1 else {
            showClipboardHistory()
            return
        }

        showingClipboard = false
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

    func togglePreview() {
        guard !showingClipboard, results.indices.contains(selectedIndex) else { return }
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

    private func updatePreview() {
        let autoPreview = SettingsManager.shared.showPreviewOnSelect
        guard (showPreview || autoPreview), results.indices.contains(selectedIndex) else { return }
        if autoPreview {
            showPreview = true
        }
        previewResult = results[selectedIndex]
    }
}
