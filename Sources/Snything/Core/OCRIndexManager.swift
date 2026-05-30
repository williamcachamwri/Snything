import Foundation
import AppKit
import Vision

struct OCRIndexEntry: Codable {
    let path: String
    let text: String
    let timestamp: Date
}

final class OCRIndexManager: ObservableObject, @unchecked Sendable {
    static let shared = OCRIndexManager()

    @Published var isIndexing = false
    @Published var indexedCount = 0
    @Published var totalImages = 0

    private var index: [String: String] = [:] // path -> OCR text
    private let lockQueue = DispatchQueue(label: "snything.ocrindex.lock")
    private let workQueue = DispatchQueue(label: "snything.ocrindex", qos: .utility)
    private let storageKey = "snything.ocrIndex"
    private var indexTask: Task<Void, Never>?

    private init() {
        loadIndex()
    }

    // MARK: - Search

    func pathsMatching(query: String) -> [String] {
        let lower = query.lowercased()
        var copy: [String: String] = [:]
        lockQueue.sync { copy = index }
        return copy.compactMap { path, text in
            text.lowercased().contains(lower) ? path : nil
        }
    }

    func ocrText(for path: String) -> String? {
        var result: String?
        lockQueue.sync { result = index[path] }
        return result
    }

    // MARK: - Indexing

    func startBackgroundIndex(for paths: [String]) {
        indexTask?.cancel()
        indexTask = Task { [weak self] in
            guard let self else { return }
            let imagePaths = self.collectImagePaths(from: paths)
            await self.buildIndex(for: imagePaths)
        }
    }

    private func collectImagePaths(from paths: [String]) -> [String] {
        let imageExts = Set(["png", "jpg", "jpeg", "gif", "tiff", "webp", "heic", "bmp"])
        let fm = FileManager.default
        var result: [String] = []
        result.reserveCapacity(1000)

        for path in paths {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                // Enumerate directory up to depth 4, skip heavy dirs
                let url = URL(fileURLWithPath: path)
                if let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    var count = 0
                    for case let fileURL as URL in enumerator {
                        let ext = fileURL.pathExtension.lowercased()
                        if imageExts.contains(ext) {
                            result.append(fileURL.path)
                            count += 1
                            if count >= 500 { break } // Limit per scope
                        }
                        // Limit depth by checking path components
                        let depth = fileURL.pathComponents.count - url.pathComponents.count
                        if depth > 4 { enumerator.skipDescendants() }
                    }
                }
            } else {
                let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
                if imageExts.contains(ext) {
                    result.append(path)
                }
            }
        }
        return result
    }

    private func buildIndex(for imagePaths: [String]) async {
        await MainActor.run { isIndexing = true }
        await MainActor.run { indexedCount = 0 }
        await MainActor.run { totalImages = imagePaths.count }

        for path in imagePaths {
            guard !Task.isCancelled else { break }

            var alreadyIndexed = false
            lockQueue.sync { alreadyIndexed = index[path] != nil }
            if alreadyIndexed { continue }

            let text = await performOCR(path: path)
            if !text.isEmpty {
                lockQueue.sync { index[path] = text }
            }

            await MainActor.run {
                indexedCount += 1
            }
        }

        saveIndex()

        await MainActor.run { isIndexing = false }
    }

    private func performOCR(path: String) async -> String {
        let url = URL(fileURLWithPath: path)
        guard let cgImage = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast // Fast mode for indexing
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en", "vi", "zh-Hans", "ja", "ko"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return ""
        }

        guard let observations = request.results else { return "" }
        let texts = observations.compactMap { $0.topCandidates(1).first?.string }
        return texts.joined(separator: " ")
    }

    // MARK: - Persistence

    private func saveIndex() {
        var entries: [OCRIndexEntry] = []
        lockQueue.sync { entries = index.map { OCRIndexEntry(path: $0.key, text: $0.value, timestamp: Date()) } }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadIndex() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([OCRIndexEntry].self, from: data) else { return }
        lockQueue.sync {
            for entry in entries {
                index[entry.path] = entry.text
            }
        }
    }

    func invalidate(path: String) {
        lockQueue.sync { _ = index.removeValue(forKey: path) }
    }
}
