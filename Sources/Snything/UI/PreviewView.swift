import SwiftUI
import AppKit

struct PreviewView: View {
    let result: SearchResult

    var body: some View {
        Group {
            switch result.kind {
            case .folder:
                FolderPreviewView(url: result.url)
                    .id(result.url)
            case .application:
                AppBundlePreviewView(url: result.url)
                    .id(result.url)
            case .image:
                ImagePreviewView(url: result.url)
                    .id(result.url)
            case .code, .document:
                CodePreviewView(url: result.url)
                    .id(result.url)
            case .file, .archive, .audio, .video:
                FileContextPreviewView(url: result.url)
                    .id(result.url)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Folder Preview (Tree Structure + Git)

struct FolderPreviewView: View {
    let url: URL
    @State private var tree: TreeNode? = nil
    @State private var totalSize: Int64 = 0
    @State private var fileCount: Int = 0
    @State private var dirCount: Int = 0
    @State private var gitInfo: GitInfo? = nil
    @State private var isLoading = true
    @State private var selectedURL: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if let git = gitInfo {
                gitBar(git: git)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            Divider()
                .background(Color.white.opacity(0.08))

            if isLoading {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning folder structure...")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else if tree == nil || tree!.children.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("Empty folder")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(tree!.children) { child in
                            TreeNodeView(node: child, depth: 0, selectedURL: $selectedURL, onOpen: { url in
                                NSWorkspace.shared.open(url)
                            })
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: url) {
            await loadFolderData()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                Text(url.lastPathComponent)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            HStack(spacing: 12) {
                Label("\(fileCount + dirCount) items", systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Label(byteCount(totalSize), systemImage: "externaldrive")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Label("\(fileCount)f / \(dirCount)d", systemImage: "arrow.down.circle")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }

    private func gitBar(git: GitInfo) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "branch")
                    .font(.system(size: 10, weight: .bold))
                Text(git.branch)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(.purple)

            if git.ahead > 0 || git.behind > 0 {
                Text("\u{2191}\(git.ahead) \u{2193}\(git.behind)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
            }

            if git.modified > 0 {
                Label("\(git.modified)", systemImage: "pencil.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.yellow)
            }
            if git.untracked > 0 {
                Label("\(git.untracked)", systemImage: "plus.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
            }
            if git.staged > 0 {
                Label("\(git.staged)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.purple.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func loadFolderData() async {
        isLoading = true
        defer { isLoading = false }

        let rootNode = buildTree(at: url, depth: 0, maxDepth: 3, maxChildren: 80)
        let stats = computeRecursiveStats(at: url)
        let git = detectGitStatus(at: url)

        await MainActor.run {
            self.tree = rootNode
            self.totalSize = stats.size
            self.fileCount = stats.fileCount
            self.dirCount = stats.dirCount
            self.gitInfo = git
        }
    }

    private func detectGitStatus(at root: URL) -> GitInfo? {
        let gitDir = root.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else { return nil }

        // Read branch from HEAD
        let headFile = gitDir.appendingPathComponent("HEAD")
        guard let head = try? String(contentsOf: headFile, encoding: .utf8) else { return nil }
        let branch = head.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "/").last ?? "unknown"

        var modified = 0
        var untracked = 0
        var staged = 0
        var ahead = 0
        var behind = 0

        // Use git status --porcelain
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", root.path, "status", "--porcelain"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: .newlines) {
                    guard line.count >= 2 else { continue }
                    let indexStatus = line.prefix(1)
                    let workTreeStatus = line.dropFirst().prefix(1)
                    if indexStatus != " " && indexStatus != "?" { staged += 1 }
                    if workTreeStatus != " " { modified += 1 }
                    if indexStatus == "?" { untracked += 1; modified -= 1 }
                }
            }
        } catch {}

        // Use git rev-list to check ahead/behind
        let revTask = Process()
        revTask.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        revTask.arguments = ["-C", root.path, "rev-list", "--left-right", "--count", "HEAD...@{upstream}"]
        let revPipe = Pipe()
        revTask.standardOutput = revPipe
        revTask.standardError = Pipe()
        do {
            try revTask.run()
            let data = revPipe.fileHandleForReading.readDataToEndOfFile()
            revTask.waitUntilExit()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespaces) {
                let parts = output.components(separatedBy: "\t")
                if parts.count == 2 {
                    ahead = Int(parts[0]) ?? 0
                    behind = Int(parts[1]) ?? 0
                }
            }
        } catch {}

        return GitInfo(branch: branch, modified: modified, untracked: untracked, staged: staged, ahead: ahead, behind: behind)
    }

    private func byteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct TreeNode: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [TreeNode] = []
    var size: Int64?
    var isExpanded: Bool = false
}

struct TreeNodeView: View {
    let node: TreeNode
    let depth: Int
    @Binding var selectedURL: URL?
    let onOpen: (URL) -> Void
    @State private var isExpanded: Bool = false

    private var isSelected: Bool {
        selectedURL == node.url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowView

            if isExpanded && !node.children.isEmpty {
                ForEach(node.children) { child in
                    TreeNodeView(node: child, depth: depth + 1, selectedURL: $selectedURL, onOpen: onOpen)
                }
            }
        }
    }

    private var rowView: some View {
        HStack(spacing: 4) {
            // Indentation
            ForEach(0..<depth, id: \.self) { _ in
                Text("  ")
                    .font(.system(size: 12, design: .monospaced))
            }

            // Disclosure triangle (separate tap target)
            if node.isDirectory && !node.children.isEmpty {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 14)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    }
            } else {
                Text(" ")
                    .frame(width: 14)
            }

            // File/Folder icon
            Image(systemName: node.isDirectory ? "folder.fill" : iconForFile(node.url))
                .font(.system(size: 11))
                .foregroundColor(node.isDirectory ? .blue : colorForFile(node.url))
                .frame(width: 16)

            // Name
            Text(node.name)
                .font(.system(size: 12, weight: node.isDirectory ? .semibold : .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(1)

            Spacer()

            // Size
            if let size = node.size {
                Text(byteCount(size))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedURL = node.url
            if node.isDirectory {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }
        }
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                onOpen(node.url)
            }
        )
        .onDrag {
            let provider = NSItemProvider(contentsOf: node.url) ?? NSItemProvider()
            return provider
        }
        .contextMenu {
            Button("Open") {
                onOpen(node.url)
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(node.url.path, inFileViewerRootedAtPath: "")
            }
            Divider()
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.url.path, forType: .string)
            }
            Button("Move to Trash") {
                do {
                    try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
                } catch {
                    print("[Preview] failed to trash \(node.url.path): \(error)")
                }
            }
        }
        .id(node.url)
    }

    private func iconForFile(_ url: URL) -> String {
        switch SearchResult.kind(from: url) {
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .document: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .archive: return "archivebox"
        default: return "doc"
        }
    }

    private func colorForFile(_ url: URL) -> Color {
        switch SearchResult.kind(from: url) {
        case .image: return .pink
        case .video: return .red
        case .audio: return .orange
        case .document: return .cyan
        case .code: return .green
        case .archive: return .gray
        default: return .secondary
        }
    }

    private func byteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Tree Helpers

func buildTree(at root: URL, depth: Int, maxDepth: Int, maxChildren: Int) -> TreeNode {
    let fm = FileManager.default
    let homeDir = fm.homeDirectoryForCurrentUser
    let isHugeDir = root.path == homeDir.path || root.path.hasPrefix(homeDir.path) && root.pathComponents.count <= homeDir.pathComponents.count + 1
    let actualMaxDepth = isHugeDir ? 1 : maxDepth
    let actualMaxChildren = isHugeDir ? 30 : maxChildren

    var children: [TreeNode] = []

    if depth < actualMaxDepth,
       let contents = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: []) {
        let sorted = contents.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for item in sorted.prefix(actualMaxChildren) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                let child = buildTree(at: item, depth: depth + 1, maxDepth: maxDepth, maxChildren: maxChildren)
                children.append(child)
            } else {
                let size = item.fileSize() ?? 0
                children.append(TreeNode(name: item.lastPathComponent, url: item, isDirectory: false, size: size))
            }
        }
    }

    return TreeNode(name: root.lastPathComponent, url: root, isDirectory: true, children: children)
}

func computeRecursiveStats(at root: URL) -> (size: Int64, fileCount: Int, dirCount: Int) {
    let fm = FileManager.default
    let homeDir = fm.homeDirectoryForCurrentUser
    let isHugeDir = root.path == homeDir.path || root.path.hasPrefix(homeDir.path) && root.pathComponents.count <= homeDir.pathComponents.count + 1
    if isHugeDir {
        return (0, 0, 0)
    }

    var totalSize: Int64 = 0
    var fileCount = 0
    var dirCount = 0
    var visited = 0

    guard let enumerator = fm.enumerator(
        at: root,
        includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
        options: [],
        errorHandler: nil
    ) else { return (0, 0, 0) }

    for case let item as URL in enumerator {
        autoreleasepool {
            if let values = try? item.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == true {
                dirCount += 1
            } else {
                fileCount += 1
                if let size = try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        visited += 1
        if visited >= 2000 { break }
    }
    return (totalSize, fileCount, dirCount)
}

struct GitInfo {
    let branch: String
    let modified: Int
    let untracked: Int
    let staged: Int
    let ahead: Int
    let behind: Int
}

// MARK: - App Bundle Preview

struct AppBundlePreviewView: View {
    let url: URL
    @State private var tree: TreeNode? = nil
    @State private var appIcon: NSImage? = nil
    @State private var appVersion: String = ""
    @State private var bundleID: String = ""
    @State private var totalSize: Int64 = 0
    @State private var fileCount: Int = 0
    @State private var dirCount: Int = 0
    @State private var isLoading = true
    @State private var selectedURL: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()
                .background(Color.white.opacity(0.08))

            if isLoading {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning bundle structure...")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else if tree == nil || tree!.children.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "app")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("Empty bundle")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(tree!.children) { child in
                            TreeNodeView(node: child, depth: 0, selectedURL: $selectedURL, onOpen: { url in
                                NSWorkspace.shared.open(url)
                            })
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: url) {
            await loadBundleData()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .cornerRadius(10)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.purple)
                        .frame(width: 44, height: 44)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    if !appVersion.isEmpty || !bundleID.isEmpty {
                        Text("\(appVersion)  ·  \(bundleID)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Label("\(fileCount + dirCount) items", systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Label(byteCount(totalSize), systemImage: "externaldrive")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Label("\(fileCount)f / \(dirCount)d", systemImage: "arrow.down.circle")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }

    private func loadBundleData() async {
        isLoading = true
        defer { isLoading = false }

        await MainActor.run {
            self.appIcon = NSWorkspace.shared.icon(forFile: url.path)
        }

        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        if let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] {
            await MainActor.run {
                self.appVersion = dict["CFBundleShortVersionString"] as? String
                    ?? dict["CFBundleVersion"] as? String
                    ?? ""
                self.bundleID = dict["CFBundleIdentifier"] as? String ?? ""
            }
        }

        let rootTree = buildTree(at: url, depth: 0, maxDepth: 3, maxChildren: 80)
        let stats = computeRecursiveStats(at: url)

        await MainActor.run {
            self.tree = rootTree
            self.totalSize = stats.size
            self.fileCount = stats.fileCount
            self.dirCount = stats.dirCount
        }
    }

    private func byteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - File Context Preview (parent folder tree + highlighted file)

struct FileContextPreviewView: View {
    let url: URL
    @State private var tree: TreeNode? = nil
    @State private var selectedURL: URL? = nil
    @State private var parentSize: Int64 = 0
    @State private var fileCount: Int = 0
    @State private var dirCount: Int = 0
    @State private var isLoading = true

    private var fileName: String { url.lastPathComponent }
    private var parentURL: URL { url.deletingLastPathComponent() }
    private var fileSize: Int64? { url.fileSize() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()
                .background(Color.white.opacity(0.08))

            if isLoading {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning folder structure...")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else if tree == nil || tree!.children.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("Empty folder")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(tree!.children) { child in
                                TreeNodeView(node: child, depth: 0, selectedURL: $selectedURL, onOpen: { targetURL in
                                    NSWorkspace.shared.open(targetURL)
                                })
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: selectedURL) { _, newURL in
                        if let newURL {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(newURL, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: url) {
            await loadData()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: iconForFile(url))
                    .font(.system(size: 20))
                    .foregroundColor(colorForFile(url))
                Text(fileName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            HStack(spacing: 12) {
                if let size = fileSize {
                    Label(byteCount(size), systemImage: "doc")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Label("in \(parentURL.lastPathComponent)", systemImage: "folder")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Label("\(fileCount)f / \(dirCount)d", systemImage: "arrow.down.circle")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let parent = parentURL
        let rootNode = buildTree(at: parent, depth: 0, maxDepth: 3, maxChildren: 80)
        let stats = computeRecursiveStats(at: parent)

        await MainActor.run {
            self.tree = rootNode
            self.selectedURL = url
            self.parentSize = stats.size
            self.fileCount = stats.fileCount
            self.dirCount = stats.dirCount
        }
    }

    private func iconForFile(_ url: URL) -> String {
        switch SearchResult.kind(from: url) {
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .document: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .archive: return "archivebox"
        default: return "doc"
        }
    }

    private func colorForFile(_ url: URL) -> Color {
        switch SearchResult.kind(from: url) {
        case .image: return .pink
        case .video: return .red
        case .audio: return .orange
        case .document: return .cyan
        case .code: return .green
        case .archive: return .gray
        default: return .secondary
        }
    }

    private func byteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Image Preview

struct ImagePreviewView: View {
    let url: URL
    @State private var nsImage: NSImage? = nil
    @State private var exif: EXIFData? = nil
    @State private var isLoading = true
    @State private var ocrTexts: [OCRText] = []
    @State private var showOCR = false
    @State private var hoveredOCRID: UUID? = nil
    @State private var showOCRPanel = false

    private var allOCRText: String {
        ocrTexts.map(\.text).joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Image area only — GeometryReader measures just this region
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.15)

                    if let nsImage {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(12)
                    } else if !isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("Unable to load image")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    if showOCR, let nsImage {
                        ocrOverlay(imageSize: nsImage.size, containerSize: geo.size)
                    }

                    // OCR toggle buttons
                    if !ocrTexts.isEmpty {
                        VStack {
                            HStack {
                                Spacer()
                                VStack(spacing: 6) {
                                    Button {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            showOCR.toggle()
                                        }
                                    } label: {
                                        Image(systemName: showOCR ? "text.viewfinder" : "text.viewfinder")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(showOCR ? .accentColor : .white)
                                            .padding(8)
                                            .background(
                                                Circle()
                                                    .fill(Color.black.opacity(0.5))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .help(showOCR ? "Hide OCR" : "Show OCR text")

                                    Button {
                                        showOCRPanel = true
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(
                                                Circle()
                                                    .fill(Color.black.opacity(0.5))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy / select text")
                                }
                                .padding(12)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let exif {
                exifBar(data: exif)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .sheet(isPresented: $showOCRPanel) {
            OCRTextPanel(text: allOCRText)
        }
        .task(id: url) {
            await loadImageAndExif()
            await loadOCR()
        }
    }

    @ViewBuilder
    private func ocrOverlay(imageSize: NSSize, containerSize: CGSize) -> some View {
        let fitted = fittedImageRect(imageSize: imageSize, containerSize: containerSize, padding: 12)
        ZStack(alignment: .topLeading) {
            ForEach(ocrTexts) { item in
                let box = item.boundingBox
                // Vision: origin bottom-left, normalized [0,1]
                // SwiftUI ZStack(alignment: .topLeading): origin top-left
                let x = box.minX * fitted.width
                let y = (1.0 - box.maxY) * fitted.height
                let w = max(box.width * fitted.width, 1)
                let h = max(box.height * fitted.height, 1)

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(hoveredOCRID == item.id ? Color.accentColor.opacity(0.25) : Color.yellow.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(hoveredOCRID == item.id ? Color.accentColor : Color.yellow.opacity(0.6), lineWidth: 1)
                        )

                    if hoveredOCRID == item.id {
                        Text(item.text)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(3)
                            .offset(y: -22)
                    }
                }
                .frame(width: w, height: h)
                .offset(x: x, y: y)
                .contentShape(Rectangle())
                .onHover { hovering in
                    hoveredOCRID = hovering ? item.id : nil
                }
                .onTapGesture {
                    copyToClipboard(item.text)
                }
            }
        }
        .frame(width: fitted.width, height: fitted.height)
        .position(x: fitted.midX, y: fitted.midY)
    }

    private func fittedImageRect(imageSize: NSSize, containerSize: CGSize, padding: CGFloat) -> CGRect {
        let availW = containerSize.width - padding * 2
        let availH = containerSize.height - padding * 2
        let imgAspect = imageSize.width / imageSize.height
        let containerAspect = availW / availH
        if imgAspect > containerAspect {
            let w = availW
            let h = w / imgAspect
            return CGRect(x: (containerSize.width - w) / 2,
                          y: (containerSize.height - h) / 2,
                          width: w, height: h)
        } else {
            let h = availH
            let w = h * imgAspect
            return CGRect(x: (containerSize.width - w) / 2,
                          y: (containerSize.height - h) / 2,
                          width: w, height: h)
        }
    }

    private func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private func exifBar(data: EXIFData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let camera = data.camera {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                    Text(camera)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.secondary.opacity(0.9))
            }

            HStack(spacing: 10) {
                if let lens = data.lens {
                    Label(lens, systemImage: "aperture")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                if let settings = data.settings {
                    Label(settings, systemImage: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                if let date = data.dateTaken {
                    Label(date, systemImage: "calendar")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                if let dims = data.dimensions {
                    Label(dims, systemImage: "crop")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
            }
            .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func loadImageAndExif() async {
        isLoading = true
        defer { isLoading = false }

        let (image, exifData) = await FastImageLoader.load(url: url)
        await MainActor.run {
            self.nsImage = image
            withAnimation(.easeOut(duration: 0.2)) {
                self.exif = exifData
            }
        }
    }

    private func loadOCR() async {
        let texts = await ImageOCRService.recognizeText(in: url)
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.25)) {
                self.ocrTexts = texts
            }
        }
    }
}

struct OCRTextPanel: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recognized Text")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Button("Copy All") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(text, forType: .string)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()

            Divider()

            ScrollView {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct EXIFData {
    let camera: String?
    let lens: String?
    let settings: String?
    let dateTaken: String?
    let dimensions: String?
}

enum FastImageLoader {
    static func load(url: URL) async -> (NSImage?, EXIFData?) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return (nil, nil)
        }

        // Extract EXIF first (cheap)
        let exif = extractEXIF(from: source, url: url)

        // Fast thumbnail: 800px max, never full decode
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1200
        ]

        var cgImage: CGImage?
        if let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) {
            cgImage = thumb
        } else if let full = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            cgImage = full
        }

        guard let cgImage else { return (nil, exif) }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return (nsImage, exif)
    }

    private static func extractEXIF(from source: CGImageSource, url: URL) -> EXIFData? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        // Camera
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let exifAux = props[kCGImagePropertyExifAuxDictionary] as? [CFString: Any]

        let make = (tiff?[kCGImagePropertyTIFFMake] as? String)?.trimmingCharacters(in: .whitespaces)
        let model = (tiff?[kCGImagePropertyTIFFModel] as? String)?.trimmingCharacters(in: .whitespaces)
        var camera: String?
        if let make, let model {
            camera = "\(make) \(model)"
        } else if let model {
            camera = model
        }

        // Lens
        let lensModel = exifAux?[kCGImagePropertyExifAuxLensModel] as? String
        let lens = lensModel?.trimmingCharacters(in: .whitespaces)

        // Settings: ISO, Aperture, Shutter, Focal
        var settingsParts: [String] = []
        if let iso = exif?[kCGImagePropertyExifISOSpeedRatings] as? [Int], let firstISO = iso.first {
            settingsParts.append("ISO \(firstISO)")
        }
        if let fNumber = exif?[kCGImagePropertyExifFNumber] as? Double {
            settingsParts.append(String(format: "f/%.1f", fNumber))
        }
        if let expTime = exif?[kCGImagePropertyExifExposureTime] as? Double, expTime > 0 {
            if expTime >= 1 {
                settingsParts.append(String(format: "%.1fs", expTime))
            } else {
                settingsParts.append("1/\(Int(1.0 / expTime))s")
            }
        }
        if let focal = exif?[kCGImagePropertyExifFocalLength] as? Double {
            settingsParts.append(String(format: "%.0fmm", focal))
        }
        let settings = settingsParts.isEmpty ? nil : settingsParts.joined(separator: "  ")

        // Date taken
        var dateTaken: String?
        if let dateStr = exif?[kCGImagePropertyExifDateTimeOriginal] as? String {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
            if let date = fmt.date(from: dateStr) {
                let out = DateFormatter()
                out.dateStyle = .medium
                out.timeStyle = .short
                dateTaken = out.string(from: date)
            } else {
                dateTaken = dateStr
            }
        }

        // Dimensions
        var dimensions: String?
        let width = props[kCGImagePropertyPixelWidth] as? Int
        let height = props[kCGImagePropertyPixelHeight] as? Int
        if let width, let height {
            dimensions = "\(width) x \(height)"
        }

        return EXIFData(
            camera: camera,
            lens: lens,
            settings: settings,
            dateTaken: dateTaken,
            dimensions: dimensions
        )
    }
}

// MARK: - Code Preview

struct CodePreviewView: View {
    let url: URL
    @State private var attributed: AttributedString = ""
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(lineCount) lines")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
                .background(Color.white.opacity(0.08))

            ScrollView(.vertical) {
                Text(attributed)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).opacity(0.95))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: url) {
            await loadCode()
        }
    }

    private var lineCount: Int {
        let str = String(attributed.characters)
        return str.components(separatedBy: .newlines).count
    }

    private func loadCode() async {
        isLoading = true
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let raw = String(data: data, encoding: .utf8)?.prefix(5000) else {
            isLoading = false
            return
        }
        attributed = SyntaxHighlighter.highlight(String(raw), for: url.pathExtension)
        isLoading = false
    }
}

// MARK: - Generic Preview

struct GenericPreviewView: View {
    let result: SearchResult

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 80, height: 80)
                Image(systemName: iconName)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)
            }

            VStack(spacing: 6) {
                Text(result.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text(result.subtitle.isEmpty ? result.parentPath : result.subtitle)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                infoRow("Kind", value: result.kind.rawValue.capitalized)
                if let size = result.size {
                    infoRow("Size", value: byteCount(size))
                }
                if let date = result.modifiedDate {
                    infoRow("Modified", value: formatDate(date))
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.vertical, 20)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch result.kind {
        case .application: return "app.fill"
        case .video: return "film.fill"
        case .audio: return "music.note"
        case .document: return "doc.fill"
        case .archive: return "archivebox.fill"
        default: return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch result.kind {
        case .application: return .purple
        case .video: return .red
        case .audio: return .orange
        case .document: return .cyan
        case .archive: return .gray
        default: return .secondary
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private func byteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Syntax Highlighter

enum SyntaxHighlighter {
    static func highlight(_ code: String, for ext: String) -> AttributedString {
        var attr = AttributedString(code)
        let baseColor = NSColor(red: 0.85, green: 0.87, blue: 0.91, alpha: 1.0)
        attr.foregroundColor = Color(nsColor: baseColor)

        let (keywords, strings, comments, numbers) = patterns(for: ext)

        applyPattern(code, &attr, pattern: keywords, color: NSColor(red: 0.98, green: 0.45, blue: 0.56, alpha: 1.0))
        applyPattern(code, &attr, pattern: strings, color: NSColor(red: 0.56, green: 0.89, blue: 0.52, alpha: 1.0))
        applyPattern(code, &attr, pattern: comments, color: NSColor(red: 0.40, green: 0.45, blue: 0.52, alpha: 1.0))
        applyPattern(code, &attr, pattern: numbers, color: NSColor(red: 0.96, green: 0.76, blue: 0.35, alpha: 1.0))

        return attr
    }

    private static func applyPattern(_ code: String, _ attr: inout AttributedString, pattern: String, color: NSColor) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let nsString = code as NSString
        let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: nsString.length))
        for match in matches.reversed() {
            if let range = Range(match.range, in: attr) {
                attr[range].foregroundColor = Color(nsColor: color)
            }
        }
    }

    private static func patterns(for ext: String) -> (keywords: String, strings: String, comments: String, numbers: String) {
        let commonKeywords = "\\b(let|var|func|class|struct|enum|protocol|extension|import|return|if|else|for|while|switch|case|break|continue|guard|try|catch|throw|async|await|self|init|deinit|static|public|private|internal|open|fileprivate|override|final|mutating|lazy|weak|strong|associatedtype|typealias|where|in|is|as|nil|true|false|new|this|const|function|className|def|return|yield|import|from|export|default|typeof|instanceof|void|protected|extends|implements|interface|package|super|try|catch|finally|throw|throws|boolean|byte|char|double|float|int|long|short|String|Array|Map|Set|Object|val|fun|data|sealed|abstract|inline|crossinline|noinline|reified|out|by|get|set|field|property|constructor|companion|object|interface|when|using|namespace|template|typename|explicit|implicit|virtual|override|final|const|constexpr|auto|decltype|sizeof|alignof|noexcept|concept|requires|co_await|co_return|co_yield|module|import|export)\\b"
        let strings = "(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*'|\"\"\"[\\s\\S]*?\"\"\"|'''[\\s\\S]*?''')"
        let comments = "(//[^\\n]*|/\\*[\\s\\S]*?\\*/|#[^\\n]*)"
        let numbers = "\\b(0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?)\\b"
        return (commonKeywords, strings, comments, numbers)
    }
}


