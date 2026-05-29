import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SearchResult: Identifiable, Hashable, Sendable {
    var id: String { path }
    let url: URL
    let name: String
    let path: String
    let kind: ResultKind
    let size: Int64?
    let modifiedDate: Date?
    let relevanceScore: Double

    var displayName: String { name }
    var parentPath: String { url.deletingLastPathComponent().path }

    enum ResultKind: String, Sendable {
        case file
        case folder
        case application
        case image
        case video
        case audio
        case document
        case archive
        case code
    }

    static func kind(from url: URL) -> ResultKind {
        let ext = url.pathExtension.lowercased()
        if ext == "app" { return .application }
        if ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "heic",
            "cr2", "cr3", "nef", "nrw", "arw", "sr2", "raf", "dng", "orf", "rw2", "pef",
            "raw", "mos", "3fr", "erf", "kdc", "mos", "iiq", "x3f"].contains(ext) { return .image }
        if ["mp4", "mov", "avi", "mkv", "wmv", "flv", "m4v"].contains(ext) { return .video }
        if ["mp3", "aac", "wav", "flac", "m4a", "ogg", "wma"].contains(ext) { return .audio }
        if ["pdf", "doc", "docx", "txt", "rtf", "pages", "numbers", "keynote", "md", "epub"].contains(ext) { return .document }
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"].contains(ext) { return .archive }
        if ["swift", "c", "cpp", "h", "hpp", "m", "mm", "py", "rb", "go", "rs", "java", "kt", "js", "ts", "html", "css", "json", "xml", "sql", "sh", "zsh", "bash"].contains(ext) { return .code }
        if url.hasDirectoryPath { return .folder }
        return .file
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.path == rhs.path
    }
}
