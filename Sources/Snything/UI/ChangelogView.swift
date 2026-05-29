import SwiftUI

struct ChangelogView: View {
    @StateObject private var updateManager = UpdateManager.shared
    @State private var isHoveringInstall = false
    @State private var isHoveringSkip = false
    @State private var appearPhase = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header with version badge
            headerSection
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 16)

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, 20)

            // Scrollable release notes
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if updateManager.alertReleaseNotes.isEmpty {
                        Text("A new version of Snything is available with improvements and bug fixes.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    } else {
                        ChangelogMarkdownView(text: updateManager.alertReleaseNotes)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: .infinity)

            // Status message
            if let status = updateManager.statusMessage {
                Text(status)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Action buttons
            actionButtons
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .padding(.top, 12)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.15), .cyan.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.3), .cyan.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 68, height: 68)

                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .cyan],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .offset(y: appearPhase == 0 ? 10 : 0)
            .opacity(appearPhase == 0 ? 0 : 1)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: appearPhase)

            VStack(spacing: 6) {
                Text("New Update Available")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    versionBadge

                    Text("is ready to install")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .offset(y: appearPhase == 0 ? 8 : 0)
            .opacity(appearPhase == 0 ? 0 : 1)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15), value: appearPhase)
        }
        .onAppear { appearPhase = 1 }
    }

    private var versionBadge: some View {
        Text("v\(updateManager.alertVersion)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Skip button
            Button {
                ChangelogWindowController.shared.dismissAnimated()
            } label: {
                Text("Later")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isHoveringSkip ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isHoveringSkip ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(isHoveringSkip ? 0.12 : 0.06), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringSkip = $0 }

            // Install button with shimmer effect
            Button {
                updateManager.installUpdate()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Install Update")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(
                    color: .accentColor.opacity(isHoveringInstall ? 0.4 : 0.2),
                    radius: isHoveringInstall ? 12 : 8,
                    x: 0,
                    y: isHoveringInstall ? 4 : 2
                )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringInstall = $0 }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHoveringInstall)
        }
    }
}

// MARK: - Markdown-like parser for release notes

struct ChangelogMarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseBlocks(), id: \.id) { block in
                blockView(for: block)
            }
        }
    }

    private func blockView(for block: ChangelogBlock) -> some View {
        Group {
            switch block.type {
            case .heading:
                Text(block.content)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 4)

            case .subheading:
                Text(block.content)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .padding(.top, 2)

            case .bullet:
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    Text(block.content)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .numbered:
                HStack(alignment: .top, spacing: 8) {
                    Text("\(block.number).")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                        .frame(width: 18, alignment: .trailing)
                        .padding(.top, 1)

                    Text(block.content)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .code:
                Text(block.content)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .paragraph:
                Text(block.content)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func parseBlocks() -> [ChangelogBlock] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [ChangelogBlock] = []
        var currentParagraph = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    blocks.append(ChangelogBlock(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }
                continue
            }

            // Heading: ## or ###
            if trimmed.hasPrefix("## ") {
                if !currentParagraph.isEmpty {
                    blocks.append(ChangelogBlock(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }
                let content = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                blocks.append(ChangelogBlock(type: .heading, content: content))
                continue
            }

            if trimmed.hasPrefix("### ") {
                if !currentParagraph.isEmpty {
                    blocks.append(ChangelogBlock(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }
                let content = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                blocks.append(ChangelogBlock(type: .subheading, content: content))
                continue
            }

            // Bullet: - or *
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !currentParagraph.isEmpty {
                    blocks.append(ChangelogBlock(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }
                let content = String(trimmed.dropFirst(2))
                blocks.append(ChangelogBlock(type: .bullet, content: content))
                continue
            }

            // Numbered: 1. 2. etc
            if let match = trimmed.range(of: "^\\d+\\.\\s", options: .regularExpression) {
                if !currentParagraph.isEmpty {
                    blocks.append(ChangelogBlock(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }
                let prefix = String(trimmed[match])
                let numStr = prefix.trimmingCharacters(in: .whitespaces).dropLast()
                let number = Int(numStr) ?? 0
                let content = String(trimmed.dropFirst(prefix.count))
                blocks.append(ChangelogBlock(type: .numbered, content: content, number: number))
                continue
            }

            // Code block (indented or backticks)
            if trimmed.hasPrefix("```") {
                if !currentParagraph.isEmpty {
                    blocks.append(ChangelogBlock(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }
                continue
            }

            // Collect paragraph
            if currentParagraph.isEmpty {
                currentParagraph = trimmed
            } else {
                currentParagraph += " " + trimmed
            }
        }

        if !currentParagraph.isEmpty {
            blocks.append(ChangelogBlock(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespaces)))
        }

        return blocks
    }
}

struct ChangelogBlock: Identifiable {
    let id = UUID()
    let type: BlockType
    let content: String
    var number: Int = 0

    enum BlockType {
        case heading, subheading, bullet, numbered, code, paragraph
    }
}
