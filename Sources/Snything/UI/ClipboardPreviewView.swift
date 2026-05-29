import SwiftUI

struct ClipboardPreviewView: View {
    let item: ClipboardItem
    var onClearAll: () -> Void

    @State private var sourceAppIcon: NSImage? = nil
    @State private var imageContent: NSImage? = nil
    @State private var isHoveringClear = false

    var body: some View {
        VStack(spacing: 0) {
            // Main content area with app icon badge overlay
            contentAreaWithBadge
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom info bar
            if !item.sourceBundleID.isEmpty {
                bottomBar
            }
        }
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            loadSourceAppIcon()
            loadImageIfNeeded()
        }
    }

    @ViewBuilder
    private var contentAreaWithBadge: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main content
            contentArea

            // App icon badge overlay at bottom-right of content
            if let sourceAppIcon {
                appIconBadge(icon: sourceAppIcon)
            }

            // Clear button in top-right
            clearButton
                .padding(.top, 12)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private func appIconBadge(icon: NSImage) -> some View {
        HStack(spacing: 6) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Text(item.sourceAppName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
        .padding(.trailing, 12)
        .padding(.bottom, 12)
    }

    private var clearButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                onClearAll()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .semibold))
                Text("Clear")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isHoveringClear ? .red.opacity(0.9) : .secondary.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHoveringClear ? Color.red.opacity(0.12) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isHoveringClear ? Color.red.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHoveringClear = $0 }
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHoveringClear)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch item.type {
        case .image:
            imagePreview
        case .text, .rtf:
            textPreview
        case .url:
            urlPreview
        case .file:
            filePreview
        }
    }

    private var imagePreview: some View {
        Group {
            if let imageContent {
                Image(nsImage: imageContent)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
            } else if item.content != "Image",
                      FileManager.default.fileExists(atPath: item.content),
                      let nsImage = NSImage(contentsOfFile: item.content) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
            } else {
                placeholderView(icon: "photo", text: "Image Preview")
            }
        }
    }

    private var textPreview: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(item.content)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
                .lineSpacing(4)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var urlPreview: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 6) {
                Text("URL")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(item.content)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
            }

            Button {
                if let url = URL(string: item.content) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open in Browser", systemImage: "safari")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 40)
    }

    private var filePreview: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "doc.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }

            VStack(spacing: 6) {
                Text(URL(fileURLWithPath: item.content).lastPathComponent)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(item.content)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.selectFile(item.content, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Reveal", systemImage: "folder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: item.content))
                } label: {
                    Label("Open", systemImage: "arrow.up.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 40)
    }

    private func placeholderView(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomBar: some View {
        HStack {
            Spacer()

            Text(item.displaySubtitle)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.05))
                )
                .padding(.trailing, 12)
                .padding(.bottom, 8)
        }
    }

    private func loadSourceAppIcon() {
        guard !item.sourceBundleID.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.sourceBundleID) else { return }
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            let resized = icon.resized(to: NSSize(width: 40, height: 40))
            DispatchQueue.main.async {
                self.sourceAppIcon = resized
            }
        }
    }

    private func loadImageIfNeeded() {
        guard item.type == .image else { return }
        let path = item.content
        guard path != "Image", FileManager.default.fileExists(atPath: path) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOfFile: path) {
                DispatchQueue.main.async {
                    self.imageContent = image
                }
            }
        }
    }
}
