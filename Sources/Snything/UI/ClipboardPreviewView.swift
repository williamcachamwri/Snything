import SwiftUI

struct ClipboardPreviewView: View {
    let item: ClipboardItem
    @State private var sourceAppIcon: NSImage? = nil
    @State private var imageContent: NSImage? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom info bar with source app icon
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

            HStack(spacing: 8) {
                if let sourceAppIcon {
                    Image(nsImage: sourceAppIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                Text("Copied from \(item.sourceAppName)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }

    private func loadSourceAppIcon() {
        guard !item.sourceBundleID.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.sourceBundleID) else { return }
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            let resized = icon.resized(to: NSSize(width: 36, height: 36))
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
