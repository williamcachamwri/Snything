import SwiftUI

struct ResultRowView: View {
    let result: SearchResult
    let isSelected: Bool
    var namespace: Namespace.ID

    @State private var iconImage: NSImage?
    @State private var isHovered = false

    private let iconSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 14) {
            iconView

            VStack(alignment: .leading, spacing: 3) {
                Text(result.displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(result.parentPath)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                HStack(spacing: 6) {
                    ActionBadge(icon: "arrow.up.doc", label: "Drag")
                    ActionBadge(icon: "return", label: "Open")
                    ActionBadge(icon: "space", label: "Preview")
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            isSelected
                                ? AnyShapeStyle(LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.accentColor.opacity(0.45),
                                        Color.accentColor.opacity(0.15)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ))
                                : AnyShapeStyle(Color.clear),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                    radius: isSelected ? 8 : 0,
                    x: 0,
                    y: isSelected ? 2 : 0
                )
                .matchedGeometryEffect(id: "selection", in: namespace, isSource: isSelected)
                .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
        )
        .contentShape(Rectangle())
        .onAppear {
            loadIcon()
        }
        .onChange(of: result.url) { _, _ in
            loadIcon()
        }
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { hover in
            isHovered = hover
        }
        .onDrag {
            NSItemProvider(contentsOf: result.url) ?? NSItemProvider()
        }
    }

    @ViewBuilder
    private var iconView: some View {
        Group {
            if let iconImage {
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
        DispatchQueue.global(qos: .userInitiated).async {
            let image = NSWorkspace.shared.icon(forFile: result.url.path)
            let resized = image.resized(to: NSSize(width: iconSize * 2, height: iconSize * 2))
            DispatchQueue.main.async {
                self.iconImage = resized
            }
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

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .foregroundColor(.secondary.opacity(0.8))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        )
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
