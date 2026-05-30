import SwiftUI

struct ClipboardListView: View {
    @ObservedObject var coordinator: SearchCoordinator
    var namespace: Namespace.ID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(Array(coordinator.clipboardItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardRowView(
                            item: item,
                            isSelected: index == coordinator.selectedClipboardIndex,
                            isDeleting: coordinator.deletingClipboardID == item.id
                        )
                        .id(item.id)
                        .contentShape(Rectangle())
                        .transition(.asymmetric(
                            insertion: .offset(y: -12).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.94))
                        ))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                coordinator.selectedClipboardIndex = index
                            }
                            coordinator.openSelected()
                        }
                        .onHover { hover in
                            if hover {
                                withAnimation(.easeOut(duration: 0.08)) {
                                    coordinator.selectedClipboardIndex = index
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .background(Color.clear)
            .onChange(of: coordinator.clipboardFocusedIndex) { _, newValue in
                if coordinator.clipboardItems.indices.contains(newValue) {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(coordinator.clipboardItems[newValue].id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct ClipboardRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isDeleting: Bool
    private let iconSize: CGFloat = 32

    @State private var appIcon: NSImage? = nil
    @State private var thumbnailImage: NSImage? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail for images, app icon for everything else
            ZStack {
                if let thumbnailImage {
                    Image(nsImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: iconSize, height: iconSize)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else if let appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isDeleting ? .red.opacity(0.7) : iconColor)
                }
            }
            .frame(width: iconSize, height: iconSize)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isDeleting ? .red.opacity(0.8) : .primary)
                    .lineLimit(1)

                Text(item.displaySubtitle)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(isDeleting ? .red.opacity(0.5) : .secondary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            // Type badge
            if !isDeleting {
                Text(item.type.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(typeBadgeColor.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(typeBadgeColor.opacity(0.12))
                    )
            }

            if isSelected && !isDeleting {
                HStack(spacing: 6) {
                    ActionBadge(icon: "delete.left", label: "Delete", color: .red)
                    ActionBadge(icon: "return", label: "Paste")
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            isDeleting
                                ? AnyShapeStyle(LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.red.opacity(0.6),
                                        Color.red.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ))
                                : (isSelected
                                    ? AnyShapeStyle(LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.accentColor.opacity(0.45),
                                            Color.accentColor.opacity(0.15)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                      ))
                                    : AnyShapeStyle(Color.clear)),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isDeleting ? Color.red.opacity(0.25) : (isSelected ? Color.accentColor.opacity(0.15) : Color.clear),
                    radius: (isSelected || isDeleting) ? 8 : 0,
                    x: 0,
                    y: (isSelected || isDeleting) ? 2 : 0
                )
                .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
        )
        .contentShape(Rectangle())
        .onAppear {
            loadThumbnail()
            loadIcon()
        }
        .offset(x: isDeleting ? 60 : 0)
        .scaleEffect(isDeleting ? 0.92 : 1.0)
        .opacity(isDeleting ? 0.3 : 1.0)
        .rotationEffect(.degrees(isDeleting ? 2 : 0))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDeleting)
    }

    private var backgroundFill: Color {
        if isDeleting { return Color.red.opacity(0.12) }
        if isSelected { return Color.accentColor.opacity(0.14) }
        return Color.clear
    }

    private func loadThumbnail() {
        let path = item.content
        guard FileManager.default.fileExists(atPath: path) else { return }
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        let imageExts = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "heic"]
        guard imageExts.contains(ext) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = NSImage(contentsOfFile: path) else { return }
            let resized = image.resized(to: NSSize(width: self.iconSize * 2, height: self.iconSize * 2))
            DispatchQueue.main.async {
                self.thumbnailImage = resized
            }
        }
    }

    private func loadIcon() {
        guard item.type != .image else { return }
        guard !item.sourceBundleID.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.sourceBundleID) else { return }
            let image = NSWorkspace.shared.icon(forFile: appURL.path)
            let resized = image.resized(to: NSSize(width: self.iconSize * 2, height: self.iconSize * 2))
            DispatchQueue.main.async {
                self.appIcon = resized
            }
        }
    }

    private var iconName: String {
        switch item.type {
        case .text: return "doc.text"
        case .url: return "link"
        case .file: return "doc"
        case .image: return "photo"
        case .rtf: return "textformat"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .text: return .secondary
        case .url: return .blue
        case .file: return .orange
        case .image: return .pink
        case .rtf: return .cyan
        }
    }

    private var typeBadgeColor: Color {
        switch item.type {
        case .text: return .secondary
        case .url: return .blue
        case .file: return .orange
        case .image: return .pink
        case .rtf: return .cyan
        }
    }

}
