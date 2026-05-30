import Foundation
import AppKit

enum SmartClipboardType: String, Codable, Sendable {
    case plainText
    case url
    case email
    case phone
    case hexColor
    case rgbColor
    case json
    case code
    case filePath
    case number
    case command
    case markdown
}

struct SmartClipboardInfo: Codable, Sendable {
    let type: SmartClipboardType
    let detectedLanguage: String?       // for code: swift, js, python, etc.
    let formattedJSON: String?            // pretty-printed JSON
    let minifiedJSON: String?           // minified JSON
    let rgbR: Int?                      // for hex colors: red
    let rgbG: Int?                      // for hex colors: green
    let rgbB: Int?                      // for hex colors: blue
    let swiftUIColor: String?           // UIColor(red:..., ...)
    let cssColor: String?               // rgb(...)
    let isValidExpression: Bool?        // for numbers/math
    let expressionResult: Double?     // evaluated result
    let urlTitle: String?               // scraped page title (future)
    let urlDomain: String?              // extracted domain

    var rgbValues: (r: Int, g: Int, b: Int)? {
        guard let r = rgbR, let g = rgbG, let b = rgbB else { return nil }
        return (r, g, b)
    }
}

enum SmartClipboardService {
    static func analyze(content: String, baseType: ClipboardContentType) -> SmartClipboardInfo {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. File path check
        if baseType == .file || isFilePath(trimmed) {
            return SmartClipboardInfo(type: .filePath, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: nil)
        }

        // 2. URL check
        if baseType == .url || isURL(trimmed) {
            let domain = extractDomain(from: trimmed)
            return SmartClipboardInfo(type: .url, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: domain)
        }

        // 3. Email check
        if isEmail(trimmed) {
            return SmartClipboardInfo(type: .email, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: nil)
        }

        // 4. Phone check
        if isPhone(trimmed) {
            return SmartClipboardInfo(type: .phone, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: nil)
        }

        // 5. Hex color check
        if let hexInfo = parseHexColor(trimmed) {
            return hexInfo
        }

        // 6. RGB color check
        if let rgbInfo = parseRGBColor(trimmed) {
            return rgbInfo
        }

        // 7. JSON check
        if let jsonInfo = parseJSON(trimmed) {
            return jsonInfo
        }

        // 8. Markdown check
        if isMarkdown(trimmed) {
            return SmartClipboardInfo(type: .markdown, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: nil)
        }

        // 9. Code detection
        if let lang = detectCodeLanguage(trimmed) {
            return SmartClipboardInfo(type: .code, detectedLanguage: lang, formattedJSON: nil, minifiedJSON: nil, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: nil)
        }

        // 10. Number / expression
        if let numInfo = parseNumber(trimmed) {
            return numInfo
        }

        // 11. Command / shell
        if isShellCommand(trimmed) {
            return SmartClipboardInfo(type: .command, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: nil)
        }

        return SmartClipboardInfo(type: .plainText, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: nil)
    }

    // MARK: - Detectors

    private static func isURL(_ text: String) -> Bool {
        guard let url = URL(string: text), url.scheme != nil, url.host != nil else { return false }
        return true
    }

    private static func extractDomain(from url: String) -> String? {
        guard let u = URL(string: url) else { return nil }
        return u.host?.replacingOccurrences(of: "www.", with: "")
    }

    private static func isEmail(_ text: String) -> Bool {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isPhone(_ text: String) -> Bool {
        let digits = text.filter { $0.isNumber }
        return digits.count >= 7 && digits.count <= 15
    }

    private static func isFilePath(_ text: String) -> Bool {
        let expanded = NSString(string: text).expandingTildeInPath
        return expanded.hasPrefix("/") && FileManager.default.fileExists(atPath: expanded)
    }

    private static func parseHexColor(_ text: String) -> SmartClipboardInfo? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let patterns = [
            "^#([0-9A-Fa-f]{6})$",
            "^#([0-9A-Fa-f]{3})$",
            "^#([0-9A-Fa-f]{8})$"
        ]
        for pattern in patterns {
            if let match = trimmed.range(of: pattern, options: .regularExpression) {
                let hex = String(trimmed[match])
                let clean = hex.replacingOccurrences(of: "#", with: "")
                let r: Int, g: Int, b: Int
                if clean.count == 3 {
                    r = Int(String(clean.prefix(1)).repeated + String(clean.prefix(1)), radix: 16) ?? 0
                    g = Int(String(clean.dropFirst(1).prefix(1)).repeated + String(clean.dropFirst(1).prefix(1)), radix: 16) ?? 0
                    b = Int(String(clean.suffix(1)).repeated + String(clean.suffix(1)), radix: 16) ?? 0
                } else if clean.count == 6 {
                    r = Int(clean.prefix(2), radix: 16) ?? 0
                    g = Int(clean.dropFirst(2).prefix(2), radix: 16) ?? 0
                    b = Int(clean.suffix(2), radix: 16) ?? 0
                } else if clean.count == 8 {
                    r = Int(clean.prefix(2), radix: 16) ?? 0
                    g = Int(clean.dropFirst(2).prefix(2), radix: 16) ?? 0
                    b = Int(clean.dropFirst(4).prefix(2), radix: 16) ?? 0
                } else {
                    return nil
                }
                let swiftUI = "Color(red: \(Double(r)/255.0), green: \(Double(g)/255.0), blue: \(Double(b)/255.0))"
                let css = "rgb(\(r), \(g), \(b))"
                return SmartClipboardInfo(type: .hexColor, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: r, rgbG: g, rgbB: b, swiftUIColor: swiftUI, cssColor: css, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: nil)
            }
        }
        return nil
    }

    private static func parseRGBColor(_ text: String) -> SmartClipboardInfo? {
        let pattern = "rgb\\s*\\(\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let r = Int((text as NSString).substring(with: match.range(at: 1))) ?? 0
        let g = Int((text as NSString).substring(with: match.range(at: 2))) ?? 0
        let b = Int((text as NSString).substring(with: match.range(at: 3))) ?? 0
        let swiftUI = "Color(red: \(Double(r)/255.0), green: \(Double(g)/255.0), blue: \(Double(b)/255.0))"
        return SmartClipboardInfo(type: .rgbColor, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: r, rgbG: g, rgbB: b, swiftUIColor: swiftUI, cssColor: text, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: nil)
    }

    private static func parseJSON(_ text: String) -> SmartClipboardInfo? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return nil }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            let pretty = try JSONSerialization.data(withJSONObject: try JSONSerialization.jsonObject(with: data), options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            let prettyStr = String(data: pretty, encoding: .utf8) ?? trimmed
            let mini = try JSONSerialization.data(withJSONObject: try JSONSerialization.jsonObject(with: data), options: [.sortedKeys])
            let miniStr = String(data: mini, encoding: .utf8) ?? trimmed
            return SmartClipboardInfo(type: .json, detectedLanguage: nil, formattedJSON: prettyStr, minifiedJSON: miniStr, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: nil, expressionResult: nil, urlTitle: nil, urlDomain: nil)
        } catch {
            return nil
        }
    }

    private static func detectCodeLanguage(_ text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return nil }

        let checks: [(language: String, patterns: [String])] = [
            ("swift", ["^import ", "^struct ", "^class ", "^enum ", "^func ", "^var ", "^let ", ": some View", "@State", "@Published", "UIKit", "SwiftUI"]),
            ("javascript", ["^const ", "^let ", "^var ", "=>", "require\\(", "module\\.exports", "document\\.", "window\\.", "console\\.log"]),
            ("typescript", ["^interface ", "^type ", "\\: string", "\\: number", "\\: boolean", "as const", "enum "]),
            ("python", ["^def ", "^class ", "^import ", "^from ", "print\\(", "self\\.", "__init__", "^if __name__"]),
            ("json", ["^\\{", "^\\["]),
            ("html", ["^<!DOCTYPE", "<html", "<div", "<body", "<head", "<script", "<style"]),
            ("css", ["^\\.", "^#", "@media", "@keyframes", "px;", "em;", "rem;"]),
            ("sql", ["^SELECT ", "^INSERT ", "^UPDATE ", "^DELETE ", "^CREATE ", "^DROP ", "FROM ", "WHERE ", "JOIN "]),
            ("shell", ["^#!/bin/bash", "^#!/bin/sh", "^#!/usr/bin/env", "echo ", "cd ", "ls ", "grep ", "awk ", "sed "]),
            ("markdown", ["^# ", "^## ", "^- ", "^\\* ", "^\\[", "^> ", "^```"]),
            ("yaml", ["^---", "^\\w+:", "^- ", "  \\w+:"]),
            ("xml", ["^<?xml", "^<\\?xml", "<\\w+>"]),
            ("go", ["^package ", "^import ", "^func ", "^type ", "^struct ", "fmt\\.", ":= "],),
            ("rust", ["^fn ", "^pub ", "^use ", "^mod ", "^impl ", "^struct ", "^enum ", "let mut ", "-> "]),
            ("java", ["^public class", "^class ", "^import java", "^package ", "System\\.out", "@Override"]),
            ("kotlin", ["^fun ", "^class ", "^data class", "^val ", "^var ", "lazy ", "companion object", "override fun"]),
            ("cpp", ["^#include", "^using namespace", "^int main", "std::", "->", "const &"]),
            ("c", ["^#include", "^int main", "^void ", "printf\\(", "malloc\\("]),
            ("php", ["^<?php", "\\$\\w+", "echo ", "function ", "\\$_GET", "\\$_POST"]),
            ("ruby", ["^def ", "^class ", "^module ", "^require ", "^attr_", "@\\w+", "puts ", "end$"]),
        ]

        var scores: [String: Int] = [:]
        for (lang, patterns) in checks {
            var score = 0
            for pattern in patterns {
                if text.range(of: pattern, options: .regularExpression) != nil {
                    score += 1
                }
            }
            if score > 0 {
                scores[lang] = score
            }
        }

        if let best = scores.max(by: { $0.value < $1.value }), best.value >= 2 {
            return best.key
        }
        return nil
    }

    private static func parseNumber(_ text: String) -> SmartClipboardInfo? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        // Simple number
        if let num = Double(trimmed) {
            return SmartClipboardInfo(type: .number, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: true, expressionResult: num, urlTitle: nil, urlDomain: nil)
        }
        // Expression: 2+2, 10*5, etc.
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/%^() ")
        if trimmed.allSatisfy({ $0.unicodeScalars.allSatisfy { allowed.contains($0) } }) {
            let expr = NSExpression(format: trimmed)
            if let result = expr.expressionValue(with: nil, context: nil) as? Double {
                return SmartClipboardInfo(type: .number, detectedLanguage: nil, formattedJSON: nil, minifiedJSON: nil, rgbR: nil, rgbG: nil, rgbB: nil, swiftUIColor: nil, cssColor: nil, isValidExpression: true, expressionResult: result, urlTitle: nil, urlDomain: nil)
            }
        }
        return nil
    }

    private static func isMarkdown(_ text: String) -> Bool {
        let patterns = ["^# ", "^## ", "^- ", "^\\* ", "^\\[\\w+\\]\\(", "^> ", "^```", "\\*\\*\\w+\\*\\*", "__\\w+__"]
        var hits = 0
        for p in patterns {
            if text.range(of: p, options: .regularExpression) != nil { hits += 1 }
        }
        return hits >= 2
    }

    private static func isShellCommand(_ text: String) -> Bool {
        let commands = ["git ", "npm ", "yarn ", "pnpm ", "brew ", "curl ", "wget ", "ssh ", "scp ", "docker ", "kubectl ", "make ", "cmake ", "python ", "node ", "swift ", "cargo ", "go ", "pip ", "pip3 ", "ruby ", "bundle ", "rails ", "rake "]
        return commands.contains(where: { text.hasPrefix($0) })
    }
}

private extension String {
    var repeated: String {
        return self + self
    }
}
