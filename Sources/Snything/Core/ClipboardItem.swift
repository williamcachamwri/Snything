import Foundation

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
            return content
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

    private func formattedTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // Codable compatibility: old data missing sourceAppName/sourceBundleID
    enum CodingKeys: String, CodingKey {
        case id, content, type, sourceAppName, sourceBundleID, timestamp, characterCount
    }

    init(id: String, content: String, type: ClipboardContentType, sourceAppName: String, sourceBundleID: String, timestamp: Date, characterCount: Int) {
        self.id = id
        self.content = content
        self.type = type
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
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName) ?? "Unknown"
        sourceBundleID = try container.decodeIfPresent(String.self, forKey: .sourceBundleID) ?? ""
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        characterCount = try container.decode(Int.self, forKey: .characterCount)
    }
}
