import SwiftUI
import AppKit

struct ActionPaletteView: View {
    @ObservedObject var coordinator: SearchCoordinator
    @State private var hoveredAction: FileAction? = nil
    @State private var renameText: String = ""
    @State private var isRenaming = false
    @State private var showOpenWithMenu = false
    @State private var showTagPicker = false
    @FocusState private var renameFocus: Bool
    @State private var localMonitor: Any? = nil

    private var selectedResult: SearchResult? {
        guard !coordinator.showingClipboard,
              coordinator.results.indices.contains(coordinator.selectedIndex) else { return nil }
        return coordinator.results[coordinator.selectedIndex]
    }

    private let actions: [FileAction] = [
        FileAction(key: "o", icon: "arrow.up.forward.app", label: "Open With", color: .accentColor),
        FileAction(key: "r", icon: "pencil", label: "Rename", color: .orange),
        FileAction(key: "c", icon: "doc.on.doc", label: "Copy Path", color: .blue),
        FileAction(key: "i", icon: "info.circle", label: "Get Info", color: .secondary),
        FileAction(key: "t", icon: "tag", label: "Tags", color: .purple),
        FileAction(key: "s", icon: "square.and.arrow.up", label: "Share", color: .green),
        FileAction(key: "\u{7F}", icon: "trash", label: "Delete", color: .red),
    ]

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Palette card
            VStack(spacing: 0) {
                // Header
                HStack {
                    if let result = selectedResult {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: result.path))
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(result.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    } else {
                        Text("No file selected")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("esc to close")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider()
                    .background(Color.white.opacity(0.08))

                if isRenaming, let result = selectedResult {
                    renameView(for: result)
                } else if showOpenWithMenu, let result = selectedResult {
                    openWithView(for: result)
                } else if showTagPicker, let result = selectedResult {
                    tagPickerView(for: result)
                } else {
                    // Main action list
                    VStack(spacing: 2) {
                        ForEach(actions) { action in
                            actionRow(action)
                        }
                    }
                    .padding(6)
                }
            }
            .background(
                VisualEffectMaterialView()
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.18),
                                        Color.white.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
            .frame(width: 260)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .onAppear {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Only handle when palette is visible and not in a sub-view
                if isRenaming || showOpenWithMenu || showTagPicker {
                    if event.keyCode == 53 { // Esc goes back
                        isRenaming = false
                        showOpenWithMenu = false
                        showTagPicker = false
                        return nil
                    }
                    return event
                }
                if event.keyCode == 53 { // Esc
                    dismiss()
                    return nil
                }
                let char = event.charactersIgnoringModifiers?.lowercased() ?? ""
                if let action = actions.first(where: { $0.key == char }) {
                    execute(action)
                    return nil
                }
                if event.keyCode == 51 { // Delete key
                    if let deleteAction = actions.first(where: { $0.key == "\u{7F}" }) {
                        execute(deleteAction)
                    }
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
        }
    }

    private func actionRow(_ action: FileAction) -> some View {
        Button {
            execute(action)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: action.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(action.color)
                    .frame(width: 20)

                Text(action.label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Text(action.key == "\u{7F}" ? "⌫" : action.key.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hoveredAction?.id == action.id ? Color.accentColor.opacity(0.10) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredAction = hovering ? action : nil
        }
    }

    private func renameView(for result: SearchResult) -> some View {
        VStack(spacing: 10) {
            TextField("New name", text: $renameText)
                .font(.system(size: 13, design: .rounded))
                .textFieldStyle(.plain)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .focused($renameFocus)
                .onAppear {
                    renameText = result.name
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        renameFocus = true
                    }
                }

            HStack(spacing: 8) {
                Button("Cancel") {
                    isRenaming = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Rename") {
                    performRename(result)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
    }

    private func openWithView(for result: SearchResult) -> some View {
        let apps = appsThatCanOpen(url: result.url)
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(apps, id: \.path) { app in
                    Button {
                        let config = NSWorkspace.OpenConfiguration()
                        config.promptsUserIfNeeded = false
                        NSWorkspace.shared.open([result.url], withApplicationAt: app, configuration: config, completionHandler: nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                .resizable()
                                .frame(width: 18, height: 18)
                            Text(app.lastPathComponent)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
        }
        .frame(maxHeight: 200)
    }

    private func tagPickerView(for result: SearchResult) -> some View {
        let commonTags = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"]
        return VStack(spacing: 8) {
            Text("Add Tag")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(commonTags, id: \.self) { tag in
                    Button {
                        toggleTag(tag, for: result)
                        dismiss()
                    } label: {
                        Text(tag)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(tagColor(tag).opacity(0.15))
                            )
                            .foregroundColor(tagColor(tag))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
    }

    private func execute(_ action: FileAction) {
        guard let result = selectedResult else { return }
        switch action.key {
        case "o":
            showOpenWithMenu = true
        case "r":
            isRenaming = true
        case "c":
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(result.path, forType: .string)
            dismiss()
        case "i":
            showFinderInfo(for: result)
            dismiss()
        case "t":
            showTagPicker = true
        case "s":
            shareFile(result)
            dismiss()
        case "\u{7F}":
            coordinator.deleteSelectedFile()
            dismiss()
        default:
            break
        }
    }

    private func performRename(_ result: SearchResult) {
        let parent = result.url.deletingLastPathComponent()
        let newURL = parent.appendingPathComponent(renameText)
        do {
            try FileManager.default.moveItem(at: result.url, to: newURL)
        } catch {
            print("[Rename] Failed: \(error)")
        }
        isRenaming = false
        dismiss()
    }

    private func showFinderInfo(for result: SearchResult) {
        let script = """
        tell application "Finder"
            set theFile to POSIX file "\(result.path)" as alias
            open information window of theFile
            activate
        end tell
        """
        var errorInfo: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&errorInfo)
        }
    }

    private func shareFile(_ result: SearchResult) {
        let picker = NSSharingServicePicker(items: [result.url])
        if let window = NSApp.keyWindow {
            picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }

    private func toggleTag(_ tag: String, for result: SearchResult) {
        // Use NSWorkspace to set tags
        var tags: [String] = []
        do {
            let resourceValues = try result.url.resourceValues(forKeys: [.tagNamesKey])
            tags = resourceValues.tagNames ?? []
        } catch { }

        if tags.contains(tag) {
            tags.removeAll { $0 == tag }
        } else {
            tags.append(tag)
        }

        do {
            try (result.url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
        } catch {
            print("[Tag] Failed: \(error)")
        }
    }

    private func tagColor(_ tag: String) -> Color {
        switch tag {
        case "Red": return .red
        case "Orange": return .orange
        case "Yellow": return .yellow
        case "Green": return .green
        case "Blue": return .blue
        case "Purple": return .purple
        case "Gray": return .gray
        default: return .secondary
        }
    }

    private func appsThatCanOpen(url: URL) -> [URL] {
        guard let apps = LSCopyApplicationURLsForURL(url as CFURL, .all)?.takeRetainedValue() as? [URL] else {
            return []
        }
        return apps
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            coordinator.showActionPalette = false
        }
    }
}

struct FileAction: Identifiable {
    let id = UUID()
    let key: String
    let icon: String
    let label: String
    let color: Color
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                       y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }

    private struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
