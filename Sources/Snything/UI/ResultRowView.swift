import SwiftUI

struct ResultRowView: View {
    let result: SearchResult
    let isSelected: Bool
    var namespace: Namespace.ID
    let isDeleting: Bool
    let isPreviewOpen: Bool

    @State private var iconImage: NSImage?
    @State private var thumbnailImage: NSImage?
    @State private var isHovered = false
    @State private var tagColors: [Color] = []

    private let iconSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 14) {
            iconView

            VStack(alignment: .leading, spacing: 3) {
                Text(result.displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isDeleting ? .red.opacity(0.8) : .primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    let subtitleText = result.subtitle.isEmpty ? result.parentPath : result.subtitle
                    Text(subtitleText)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(isDeleting ? .red.opacity(0.5) : .secondary.opacity(0.8))
                        .lineLimit(1)

                    // Finder tag color dots
                    ForEach(Array(tagColors.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                    }
                }
            }

            Spacer()

            if isSelected && !isDeleting {
                HStack(spacing: 6) {
                    ActionBadge(icon: "delete.left", label: "Delete", color: .red, showLabel: !isPreviewOpen)
                    ActionBadge(icon: "return", label: "Open", showLabel: !isPreviewOpen)
                    ActionBadge(icon: "space", label: "Preview", showLabel: !isPreviewOpen)

                    // Tab hint for action palette
                    if !isPreviewOpen {
                        Text("Tab")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor.opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(Color.accentColor.opacity(0.25), lineWidth: 0.5)
                                    )
                            )
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        // Icon-only Tab badge when preview is open
                        ActionBadge(icon: "arrow.turn.right.down", label: "Tab", color: .accentColor, showLabel: false)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .task(id: result.id) {
            await loadTags()
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            isSelected
                                ? AnyShapeStyle(LinearGradient(
                                    gradient: Gradient(colors: [
                                        isDeleting ? Color.red.opacity(0.6) : Color.accentColor.opacity(0.45),
                                        isDeleting ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.15)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ))
                                : AnyShapeStyle(Color.clear),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isDeleting ? Color.red.opacity(0.25) : (isSelected ? Color.accentColor.opacity(0.15) : Color.clear),
                    radius: isSelected ? 8 : 0,
                    x: 0,
                    y: isSelected ? 2 : 0
                )
                .matchedGeometryEffect(id: "selection", in: namespace, isSource: isSelected)
                .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
        )
        .contentShape(Rectangle())
        .id(result.id)
        .onAppear {
            loadIcon()
        }
        .offset(x: isDeleting ? 60 : 0)
        .scaleEffect(isDeleting ? 0.92 : (isHovered ? 1.005 : 1.0))
        .opacity(isDeleting ? 0.3 : 1.0)
        .rotationEffect(.degrees(isDeleting ? 2 : 0))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDeleting)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { hover in
            if !isDeleting { isHovered = hover }
        }
        .onDrag {
            NSItemProvider(contentsOf: result.url) ?? NSItemProvider()
        }
    }

    private var backgroundFill: Color {
        if isDeleting { return Color.red.opacity(0.12) }
        if isSelected { return Color.accentColor.opacity(0.14) }
        return Color.clear
    }

    @ViewBuilder
    private var iconView: some View {
        Group {
            if let thumbnailImage {
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else if let iconImage {
                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: iconNameForKind(result.kind))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColorForKind(result.kind))
            }
        }
        .frame(width: iconSize, height: iconSize)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private func loadIcon() {
        if result.kind == .image {
            loadThumbnail()
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let image = NSWorkspace.shared.icon(forFile: result.url.path)
            let resized = image.resized(to: NSSize(width: iconSize * 2, height: iconSize * 2))
            DispatchQueue.main.async {
                self.iconImage = resized
            }
        }
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = NSImage(contentsOfFile: result.url.path) else { return }
            let resized = image.resized(to: NSSize(width: iconSize * 2, height: iconSize * 2))
            DispatchQueue.main.async {
                self.thumbnailImage = resized
            }
        }
    }

    @MainActor
    private func loadTags() async {
        guard let tags = try? result.url.resourceValues(forKeys: [.tagNamesKey]).tagNames else { return }
        tagColors = tags.compactMap { tagColor(from: $0) }
    }

    private func tagColor(from tag: String) -> Color? {
        // macOS Finder tags: "TagName\nColorIndex" or just "TagName"
        // Color index: 0=Gray, 1=Green, 2=Purple, 3=Blue, 4=Yellow, 5=Red, 6=Orange
        if let idx = tag.lastIndex(of: "\n") {
            let numStr = String(tag.suffix(from: tag.index(after: idx)))
            if let index = Int(numStr) {
                switch index {
                case 0: return .gray
                case 1: return .green
                case 2: return .purple
                case 3: return .blue
                case 4: return .yellow
                case 5: return .red
                case 6: return .orange
                default: break
                }
            }
        }
        // Fallback to name matching
        let name = tag.components(separatedBy: "\n").first?.lowercased() ?? ""
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "gray", "grey": return .gray
        default: return nil
        }
    }

    private func iconNameForKind(_ kind: SearchResult.ResultKind) -> String {
        switch kind {
        case .folder: return "folder.fill"
        case .application: return "app.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .audio: return "music.note"
        case .document: return "doc.fill"
        case .archive: return "archivebox.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .file: return "doc.fill"
        }
    }

    private func iconColorForKind(_ kind: SearchResult.ResultKind) -> Color {
        switch kind {
        case .folder: return .blue
        case .application: return .purple
        case .image: return .pink
        case .video: return .red
        case .audio: return .orange
        case .document: return .cyan
        case .archive: return .gray
        case .code: return .green
        case .file: return .secondary
        }
    }
}

struct ActionBadge: View {
    let icon: String
    let label: String
    var color: Color = .secondary
    var showLabel: Bool = true

    var body: some View {
        HStack(spacing: showLabel ? 3 : 0) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))

            if showLabel {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .scale(scale: 0.85).combined(with: .opacity)
                    ))
            }
        }
        .foregroundColor(color.opacity(0.85))
        .padding(.horizontal, showLabel ? 6 : 5)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(color.opacity(0.20), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: showLabel)
    }
}

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: self.size), operation: .sourceOver, fraction: 1)
        newImage.unlockFocus()
        return newImage
    }
}
