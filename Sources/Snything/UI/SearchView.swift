import SwiftUI

struct SearchView: View {
    @StateObject private var coordinator = SearchCoordinator()
    @State private var query: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool
    @Namespace private var animationNamespace

    var body: some View {
        HStack(spacing: 0) {
            resultsColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if coordinator.showPreview, let previewResult = coordinator.previewResult {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.horizontal, 12)

                PreviewView(result: previewResult)
                    .frame(maxWidth: 340, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: coordinator.showPreview)
        .onAppear {
            isSearchFocused = true
            setupKeyboardMonitor()
        }
        .onDisappear {
            coordinator.cancel()
            KeyboardManager.shared.stopMonitoring()
            KeyboardManager.shared.onKeyDown = nil
        }
        .background(Color.clear)
    }

    private var resultsColumn: some View {
        VStack(spacing: 0) {
            SearchBarView(
                query: $query,
                isSearching: coordinator.isSearching,
                onQueryChange: handleQueryChange
            )
            .focused($isSearchFocused)
            .padding(.bottom, 12)

            if coordinator.isSearching && coordinator.results.isEmpty {
                searchingIndicator
            } else if coordinator.results.isEmpty && !query.isEmpty {
                emptyState
            } else {
                ResultListView(coordinator: coordinator, namespace: animationNamespace)
            }
        }
        .padding(20)
    }

    private func handleQueryChange(_ newValue: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            let delay = SettingsManager.shared.debounceNanoseconds
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            coordinator.performSearch(query: newValue)
        }
    }

    private func setupKeyboardMonitor() {
        KeyboardManager.shared.startMonitoring()
        KeyboardManager.shared.onKeyDown = { [weak coordinator] event in
            guard let coordinator = coordinator else { return false }

            switch event.keyCode {
            case 125: // down arrow
                withAnimation(.spring(response: 0.18, dampingFraction: 0.8)) {
                    coordinator.selectNext()
                }
                self.isSearchFocused = false
                return true
            case 126: // up arrow
                withAnimation(.spring(response: 0.18, dampingFraction: 0.8)) {
                    coordinator.selectPrevious()
                }
                self.isSearchFocused = false
                return true
            case 36: // return
                coordinator.openSelected()
                return true
            case 49: // space
                if self.isSearchFocused {
                    return false // let TextField receive the space
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    coordinator.togglePreview()
                }
                return true
            case 53: // escape
                if coordinator.showPreview {
                    withAnimation(.easeOut(duration: 0.15)) {
                        coordinator.showPreview = false
                        coordinator.previewResult = nil
                    }
                    return true
                }
                self.query = ""
                coordinator.cancel()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .snythingHideWindow, object: nil)
                }
                return true
            default:
                if !self.isSearchFocused && event.characters?.count == 1 {
                    self.query += event.characters!
                    self.isSearchFocused = true
                    return true
                }
                return false
            }
        }
    }

    @ViewBuilder
    private var searchingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                .scaleEffect(0.7)
            Text("Searching...")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale))
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No results found")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
