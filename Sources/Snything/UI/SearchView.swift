import SwiftUI

struct SearchView: View {
    @StateObject private var coordinator = SearchCoordinator()
    @State private var query: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool
    @Namespace private var animationNamespace
    @State private var recentsTimer: Timer?

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
            coordinator.showRecents()
            startRecentsTimer()
        }
        .onDisappear {
            coordinator.cancel()
            KeyboardManager.shared.stopMonitoring()
            KeyboardManager.shared.onKeyDown = nil
            stopRecentsTimer()
        }
        .onChange(of: query) { _, newValue in
            if newValue.isEmpty {
                startRecentsTimer()
            } else {
                stopRecentsTimer()
            }
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
            .padding(.bottom, 8)

            // Tab switcher: Files vs Clipboard
            HStack(spacing: 8) {
                TabButton(
                    title: "Files",
                    icon: "magnifyingglass",
                    isActive: !coordinator.showingClipboard
                ) {
                    if coordinator.showingClipboard {
                        query = ""
                        coordinator.showRecents()
                    }
                }
                TabButton(
                    title: "Clipboard",
                    icon: "doc.on.clipboard",
                    isActive: coordinator.showingClipboard
                ) {
                    if !coordinator.showingClipboard {
                        query = ""
                        coordinator.showClipboardHistory()
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            if coordinator.showingRecents && coordinator.results.isEmpty {
                noRecentsState
            } else if coordinator.showingClipboard && coordinator.clipboardItems.isEmpty {
                noClipboardState
            } else if coordinator.isSearching && coordinator.results.isEmpty {
                searchingIndicator
            } else if !coordinator.showingRecents && !coordinator.showingClipboard && coordinator.results.isEmpty && !query.isEmpty {
                emptyState
            } else if coordinator.showingClipboard {
                VStack(spacing: 0) {
                    clipboardHeader
                    ClipboardListView(coordinator: coordinator, namespace: animationNamespace)
                }
            } else if coordinator.showingRecents {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.7))
                        Text("Recent Files")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
                    ResultListView(coordinator: coordinator, namespace: animationNamespace)
                }
            } else {
                ResultListView(coordinator: coordinator, namespace: animationNamespace)
            }
        }
        .padding(20)
    }

    private var clipboardHeader: some View {
        HStack {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
            Text("Clipboard History")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
            if !coordinator.clipboardItems.isEmpty {
                Button(action: {
                    ClipboardManager.shared.clearAll()
                    coordinator.showClipboardHistory()
                }) {
                    Text("Clear")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    private func handleQueryChange(_ newValue: String) {
        debounceTask?.cancel()
        if newValue.isEmpty {
            coordinator.showRecents()
            return
        }
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
                if event.modifierFlags.contains(.command) {
                    coordinator.revealSelected()
                } else {
                    coordinator.openSelected()
                }
                return true
            case 49: // space
                if self.isSearchFocused {
                    return false // let TextField receive the space
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    coordinator.togglePreview()
                }
                return true
            case 51: // delete / backspace
                if coordinator.showingClipboard {
                    coordinator.deleteSelectedClipboardItem()
                    return true
                }
                return false
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
                NotificationCenter.default.post(name: .snythingHideWindow, object: nil)
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

    private func startRecentsTimer() {
        recentsTimer?.invalidate()
        recentsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            guard coordinator.showingRecents else { return }
            coordinator.showRecents()
        }
    }

    private func stopRecentsTimer() {
        recentsTimer?.invalidate()
        recentsTimer = nil
    }

    private struct TabButton: View {
        let title: String
        let icon: String
        let isActive: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundColor(isActive ? .primary : .secondary.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private var noRecentsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No recent files")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            Text("Open or search for files to see them here")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    @ViewBuilder
    private var noClipboardState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Clipboard is empty")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            Text("Copy text, links, or files to see them here")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
