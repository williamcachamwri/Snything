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

    private let engine = FastSearchEngine.shared
    private var activeTask: Task<Void, Never>?

    func showRecents() {
        let recents = RecentFilesManager.shared.recentResults()
        results = recents
        showingRecents = true
        selectedIndex = 0
        keyboardFocusedIndex = 0
        isSearching = false
        showPreview = false
        previewResult = nil
    }

    func performSearch(query: String) {
        activeTask?.cancel()
        engine.cancel()

        guard query.count >= 1 else {
            showRecents()
            return
        }

        showingRecents = false
        isSearching = true
        selectedIndex = 0
        keyboardFocusedIndex = 0
        showPreview = false
        previewResult = nil

        let maxResults = SettingsManager.shared.maxResultsInt

        activeTask = Task { [weak self] in
            guard let self else { return }
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
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % results.count
        keyboardFocusedIndex = selectedIndex
        updatePreview()
    }

    func selectPrevious() {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + results.count) % results.count
        keyboardFocusedIndex = selectedIndex
        updatePreview()
    }

    func openSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        let result = results[selectedIndex]
        RecentFilesManager.shared.recordAccess(url: result.url)
        NSWorkspace.shared.open(result.url)
    }

    func revealSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        let result = results[selectedIndex]
        RecentFilesManager.shared.recordAccess(url: result.url)
        NSWorkspace.shared.selectFile(result.url.path, inFileViewerRootedAtPath: "")
    }

    func dragItem(at index: Int) -> NSItemProvider? {
        guard results.indices.contains(index) else { return nil }
        let result = results[index]
        RecentFilesManager.shared.recordAccess(url: result.url)
        return NSItemProvider(contentsOf: result.url)
    }

    func togglePreview() {
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

    private func updatePreview() {
        let autoPreview = SettingsManager.shared.showPreviewOnSelect
        guard (showPreview || autoPreview), results.indices.contains(selectedIndex) else { return }
        if autoPreview {
            showPreview = true
        }
        previewResult = results[selectedIndex]
    }
}
