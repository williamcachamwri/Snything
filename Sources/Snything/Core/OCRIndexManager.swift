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

    private var index: [String: String] = [:]
    private let lockQueue = DispatchQueue(label: "snything.ocrindex.lock")
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
        let paths = copy.compactMap { path, text in
            text.lowercased().contains(lower) ? path : nil
        }
        if paths.isEmpty && index.isEmpty {
            print("[OCR] Index is empty, no OCR results for '\(query)'")
        } else if paths.isEmpty {
            print("[OCR] Index has \(index.count) entries but no match for '\(query)'")
        } else {
            print("[OCR] Found \(paths.count) matches for '\(query)'")
        }
        return paths
    }

    func ocrText(for path: String) -> String? {
        var result: String?
        lockQueue.sync { result = index[path] }
        return result
    }

    var indexCount: Int {
        var count = 0
        lockQueue.sync { count = index.count }
        return count
    }

    // MARK: - On-demand OCR for search results

    /// OCR a single image on-demand (for search results not yet indexed)
    func ocrImageOnDemand(path: String) async -> String? {
        // Check if already indexed
        var existing: String?
        lockQueue.sync { existing = index[path] }
        if let existing = existing, !existing.isEmpty {
            return existing
        }

        let text = await performOCR(path: path)
        if !text.isEmpty {
            lockQueue.sync { index[path] = text }
            saveIndex()
        }
        return text.isEmpty ? nil : text
    }

    // MARK: - Indexing

    func startBackgroundIndex(for scopes: [String]) {
        indexTask?.cancel()
        indexTask = Task { [weak self] in
            guard let self else { return }
            print("[OCR] Starting background image discovery...")
            let imagePaths = await self.discoverImagesViaMdfind(scopes: scopes)
            print("[OCR] Found \(imagePaths.count) images to index (sorted by recency)")
            await self.buildIndex(for: imagePaths)
        }
    }

    /// Use mdfind -onlyin to discover images, then sort by modified date (most recent first).
    private func discoverImagesViaMdfind(scopes: [String], maxImages: Int = 5000) async -> [String] {
        let fm = FileManager.default
        let imageUTIs = [
            "public.png", "public.jpeg", "public.tiff", "public.gif",
            "public.webp", "public.heic", "public.bmp", "com.compuserve.gif"
        ]
        let typePred = imageUTIs.map { "kMDItemContentType == '\($0)'" }.joined(separator: " || ")

        var allPaths: [String] = []
        allPaths.reserveCapacity(maxImages * 2)

        for scope in scopes {
            guard !Task.isCancelled else { break }

            let resolved: String
            if scope.hasPrefix("/") {
                resolved = scope
            } else if scope == "Library" {
                // Special case: resolve to user's Library
                resolved = NSHomeDirectory() + "/Library"
            } else {
                resolved = fm.currentDirectoryPath + "/" + scope
            }

            guard fm.fileExists(atPath: resolved) else {
                print("[OCR] Scope '\(resolved)' does not exist, skipping")
                continue
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
            process.arguments = ["-onlyin", resolved, typePred]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do { try process.run() } catch { continue }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard !Task.isCancelled else { return [] }

            let paths = String(data: data, encoding: .utf8)?
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty } ?? []

            print("[OCR] mdfind -onlyin '\(resolved)' returned \(paths.count) images")
            allPaths.append(contentsOf: paths)
        }

        // Sort by modified date (most recent first) so new screenshots are indexed first
        let sorted = allPaths.sorted { a, b in
            let da = (try? fm.attributesOfItem(atPath: a)[.modificationDate] as? Date) ?? .distantPast
            let db = (try? fm.attributesOfItem(atPath: b)[.modificationDate] as? Date) ?? .distantPast
            return da > db
        }

        // Deduplicate and limit
        var seen = Set<String>()
        var unique: [String] = []
        unique.reserveCapacity(min(sorted.count, maxImages))
        for path in sorted {
            if seen.insert(path).inserted {
                unique.append(path)
                if unique.count >= maxImages { break }
            }
        }

        print("[OCR] Total unique images to index (most recent first): \(unique.count)")
        return unique
    }

    private func buildIndex(for imagePaths: [String]) async {
        await MainActor.run {
            isIndexing = true
            indexedCount = 0
            totalImages = imagePaths.count
        }

        var localCount = 0
        for path in imagePaths {
            guard !Task.isCancelled else { break }

            var alreadyIndexed = false
            lockQueue.sync { alreadyIndexed = index[path] != nil }
            if alreadyIndexed { continue }

            let text = await performOCR(path: path)
            if !text.isEmpty {
                lockQueue.sync { index[path] = text }
            }

            localCount += 1
            await MainActor.run { indexedCount = localCount }

            if localCount % 50 == 0 {
                saveIndex()
                print("[OCR] Indexed \(localCount)/\(imagePaths.count) images")
            }
        }

        saveIndex()
        await MainActor.run { indexedCount = localCount }
        print("[OCR] Done. Indexed \(localCount) images. Total in store: \(indexCount)")
        await MainActor.run { isIndexing = false }
    }

    private func performOCR(path: String) async -> String {
        let url = URL(fileURLWithPath: path)
        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en", "vi", "zh-Hans", "ja", "ko"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([request]) } catch { return "" }

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
            for entry in entries { index[entry.path] = entry.text }
        }
        print("[OCR] Loaded \(entries.count) entries from cache")
    }

    func invalidate(path: String) {
        lockQueue.sync { _ = index.removeValue(forKey: path) }
    }
}
