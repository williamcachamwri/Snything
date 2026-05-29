import SwiftUI

struct ChangelogView: View {
    @StateObject private var updateManager = UpdateManager.shared
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
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
                .offset(y: appearPhase == 0 ? 10 : 0)
                .opacity(appearPhase == 0 ? 0 : 1)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: appearPhase)

            VStack(spacing: 4) {
                Text("Update Available")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Version \(updateManager.alertVersion)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .offset(y: appearPhase == 0 ? 8 : 0)
            .opacity(appearPhase == 0 ? 0 : 1)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15), value: appearPhase)
        }
        .onAppear { appearPhase = 1 }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                ChangelogWindowController.shared.dismissAnimated()
            } label: {
                Text("Later")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Button {
                updateManager.installUpdate()
            } label: {
                Text("Install Update")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
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
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 2)

            case .subheading:
                Text(block.content)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.7))
                    .padding(.top, 1)

            case .bullet:
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{2022}")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    Text(block.content)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .numbered:
                HStack(alignment: .top, spacing: 8) {
                    Text("\(block.number).")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(width: 18, alignment: .trailing)

                    Text(block.content)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .code:
                Text(block.content)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.secondary.opacity(0.06))
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .paragraph:
                Text(block.content)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
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
