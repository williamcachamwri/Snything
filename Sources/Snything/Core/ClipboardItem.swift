import Foundation
import SwiftUI

enum ClipboardContentType: String, Codable, Sendable {
    case text
    case url
    case file
    case image
    case rtf
}

struct ClipboardItem: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let content: String
    let type: ClipboardContentType
    let smartType: SmartClipboardType
    let smartInfo: SmartClipboardInfo?
    let sourceAppName: String
    let sourceBundleID: String
    let timestamp: Date
    let characterCount: Int

    var displayTitle: String {
        switch type {
        case .text:
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
            return firstLine.isEmpty ? "(Empty text)" : String(firstLine.prefix(80))
        case .url:
            return smartInfo?.urlDomain ?? content
        case .file:
            return URL(fileURLWithPath: content).lastPathComponent
        case .image:
            return "Image \(characterCount)px"
        case .rtf:
            let plain = content.replacingOccurrences(of: "\\n", with: " ")
            return plain.prefix(80).description
        }
    }

    var displaySubtitle: String {
        let time = formattedTime(timestamp)
        return "\(sourceAppName) · \(time)"
    }

    var smartDisplayLabel: String {
        switch smartType {
        case .plainText: return "Text"
        case .url: return "URL"
        case .email: return "Email"
        case .phone: return "Phone"
        case .hexColor, .rgbColor: return "Color"
        case .json: return "JSON"
        case .code: return smartInfo?.detectedLanguage?.capitalized ?? "Code"
        case .filePath: return "File"
        case .number: return "Number"
        case .command: return "Command"
        case .markdown: return "Markdown"
        }
    }

    var smartIcon: String {
        switch smartType {
        case .plainText: return "doc.text"
        case .url: return "link"
        case .email: return "envelope"
        case .phone: return "phone"
        case .hexColor, .rgbColor: return "paintpalette"
        case .json: return "curlybraces"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .filePath: return "doc"
        case .number: return "number"
        case .command: return "terminal"
        case .markdown: return "doc.richtext"
        }
    }

    var smartColor: Color {
        switch smartType {
        case .plainText: return .secondary
        case .url: return .blue
        case .email: return .cyan
        case .phone: return .green
        case .hexColor, .rgbColor: return .pink
        case .json: return .orange
        case .code: return .purple
        case .filePath: return .orange
        case .number: return .teal
        case .command: return .gray
        case .markdown: return .indigo
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    enum CodingKeys: String, CodingKey {
        case id, content, type, smartType, smartInfo, sourceAppName, sourceBundleID, timestamp, characterCount
    }

    init(id: String, content: String, type: ClipboardContentType, smartType: SmartClipboardType, smartInfo: SmartClipboardInfo?, sourceAppName: String, sourceBundleID: String, timestamp: Date, characterCount: Int) {
        self.id = id
        self.content = content
        self.type = type
        self.smartType = smartType
        self.smartInfo = smartInfo
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.timestamp = timestamp
        self.characterCount = characterCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        type = try container.decode(ClipboardContentType.self, forKey: .type)
        smartType = try container.decodeIfPresent(SmartClipboardType.self, forKey: .smartType) ?? .plainText
        smartInfo = try container.decodeIfPresent(SmartClipboardInfo.self, forKey: .smartInfo)
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName) ?? "Unknown"
        sourceBundleID = try container.decodeIfPresent(String.self, forKey: .sourceBundleID) ?? ""
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        characterCount = try container.decode(Int.self, forKey: .characterCount)
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
