import SwiftUI
import UniformTypeIdentifiers

struct SearchView: View {
    @StateObject private var coordinator = SearchCoordinator()
    @State private var query: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool
    @Namespace private var animationNamespace
    @State private var recentsTimer: Timer?
    @State private var clipboardTimer: Timer?

    var body: some View {
        HStack(spacing: 0) {
            resultsColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if coordinator.showPreview {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.horizontal, 12)

                if coordinator.showingClipboard, let clipItem = coordinator.clipboardPreviewItem {
                    ClipboardPreviewView(
                        item: clipItem,
                        onClearAll: {
                            ClipboardManager.shared.clearAll()
                            coordinator.showClipboardHistory()
                        }
                    )
                    .frame(maxWidth: 340, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else if let previewResult = coordinator.previewResult {
                    PreviewView(result: previewResult)
                        .frame(maxWidth: 340, maxHeight: .infinity)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
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
            stopClipboardTimer()
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

            // Tab switcher: Files | Applications | Clipboard
            HStack(spacing: 8) {
                TabButton(
                    title: "Files",
                    icon: .system("magnifyingglass"),
                    isActive: !coordinator.showingApplications && !coordinator.showingClipboard
                ) {
                    if coordinator.showingApplications || coordinator.showingClipboard {
                        query = ""
                        stopClipboardTimer()
                        coordinator.showRecents()
                        startRecentsTimer()
                    }
                }
                TabButton(
                    title: "Applications",
                    icon: .system("square.grid.2x2"),
                    isActive: coordinator.showingApplications
                ) {
                    if !coordinator.showingApplications {
                        query = ""
                        stopRecentsTimer()
                        stopClipboardTimer()
                        coordinator.showApplications()
                        // Trigger search immediately for all apps if no query
                        if query.isEmpty {
                            coordinator.performSearch(query: "")
                        }
                    }
                }
                TabButton(
                    title: "Clipboard",
                    icon: .system("doc.on.clipboard"),
                    isActive: coordinator.showingClipboard
                ) {
                    if !coordinator.showingClipboard {
                        query = ""
                        stopRecentsTimer()
                        coordinator.showClipboardHistory()
                        startClipboardTimer()
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            if coordinator.showingRecents && coordinator.results.isEmpty {
                noRecentsState
            } else if coordinator.showingApplications && coordinator.results.isEmpty && !query.isEmpty {
                emptyState
            } else if coordinator.showingClipboard && coordinator.clipboardItems.isEmpty {
                noClipboardState
            } else if coordinator.isSearching && coordinator.results.isEmpty {
                searchingIndicator
            } else if !coordinator.showingRecents && !coordinator.showingApplications && !coordinator.showingClipboard && coordinator.results.isEmpty && !query.isEmpty {
                emptyState
            } else if coordinator.showingClipboard {
                VStack(spacing: 0) {
                    clipboardHeader
                    ClipboardListView(coordinator: coordinator, namespace: animationNamespace)
                }
            } else if coordinator.showingApplications {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "app.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.7))
                        Text("Applications")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
                    ResultListView(coordinator: coordinator, namespace: animationNamespace)
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
            stopClipboardTimer()
            if coordinator.showingApplications {
                coordinator.showApplications()
            } else {
                coordinator.showRecents()
                startRecentsTimer()
            }
            return
        }
        stopRecentsTimer()
        stopClipboardTimer()
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
            case 123: // left arrow
                withAnimation(.spring(response: 0.18, dampingFraction: 0.8)) {
                    self.switchToPreviousTab()
                }
                return true
            case 124: // right arrow
                withAnimation(.spring(response: 0.18, dampingFraction: 0.8)) {
                    self.switchToNextTab()
                }
                return true
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
                if self.isSearchFocused {
                    return false // let TextField handle delete
                }
                if coordinator.showingClipboard {
                    coordinator.deleteSelectedClipboardItem()
                } else if !coordinator.results.isEmpty {
                    coordinator.deleteSelectedFile()
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

    private func switchToPreviousTab() {
        if coordinator.showingClipboard {
            query = ""
            stopClipboardTimer()
            stopRecentsTimer()
            coordinator.showApplications()
            coordinator.performSearch(query: "")
        } else if coordinator.showingApplications {
            query = ""
            stopClipboardTimer()
            coordinator.showRecents()
            startRecentsTimer()
        } else {
            query = ""
            stopRecentsTimer()
            coordinator.showClipboardHistory()
            startClipboardTimer()
        }
    }

    private func switchToNextTab() {
        if coordinator.showingClipboard {
            query = ""
            stopClipboardTimer()
            coordinator.showRecents()
            startRecentsTimer()
        } else if coordinator.showingApplications {
            query = ""
            stopRecentsTimer()
            stopClipboardTimer()
            coordinator.showClipboardHistory()
            startClipboardTimer()
        } else {
            query = ""
            stopRecentsTimer()
            stopClipboardTimer()
            coordinator.showApplications()
            coordinator.performSearch(query: "")
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

    private func startClipboardTimer() {
        clipboardTimer?.invalidate()
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard coordinator.showingClipboard else { return }
            let items = ClipboardManager.shared.items
            let currentIDs = coordinator.clipboardItems.map(\.id)
            let newIDs = items.map(\.id)
            if newIDs != currentIDs {
                withAnimation(.easeOut(duration: 0.15)) {
                    coordinator.clipboardItems = items
                }
            }
        }
    }

    private func stopClipboardTimer() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }

    private struct TabButton: View {
        enum TabIcon {
            case system(String)
            case nsImage(NSImage)
        }

        let title: String
        let icon: TabIcon
        let isActive: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 4) {
                    switch icon {
                    case .system(let name):
                        Image(systemName: name)
                            .font(.system(size: 10, weight: .semibold))
                    case .nsImage(let nsImage):
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                    }
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
