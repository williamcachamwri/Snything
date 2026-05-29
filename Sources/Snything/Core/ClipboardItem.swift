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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
