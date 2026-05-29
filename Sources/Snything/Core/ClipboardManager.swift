import Foundation
import AppKit
import Combine

final class ClipboardManager: ObservableObject, @unchecked Sendable {
    static let shared = ClipboardManager()

    @Published var items: [ClipboardItem] = []

    private let maxItems = 100
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = -1
    private var timer: Timer?
    private let itemsLock = NSLock()
    private let storageKey = "snything.clipboardHistory"

    private init() {
        loadFromDisk()
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Poll at 0.3s — fast enough to catch copies, low CPU impact
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let newItem = captureItem() else { return }

        itemsLock.lock()
        defer { itemsLock.unlock() }

        // Deduplicate: don't add exact same content as the most recent item
        if let first = items.first, first.content == newItem.content, first.type == newItem.type {
            return
        }

        var newItems = [newItem] + items
        if newItems.count > maxItems {
            newItems = Array(newItems.prefix(maxItems))
        }
        items = newItems
        saveToDisk()
    }

    // MARK: - Capture

    private func captureItem() -> ClipboardItem? {
        // Get frontmost app info
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let appName = frontmostApp?.localizedName ?? "Unknown"
        let bundleID = frontmostApp?.bundleIdentifier ?? ""

        // Priority: file URLs → plain text → URLs → RTF → image
        if let filePaths = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = filePaths.first {
            return ClipboardItem(
                id: UUID().uuidString,
                content: first.path,
                type: .file,
                sourceAppName: appName,
                sourceBundleID: bundleID,
                timestamp: Date(),
                characterCount: first.path.count
            )
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Detect if it's a URL
            if let url = URL(string: string.trimmingCharacters(in: .whitespaces)),
               url.scheme != nil, url.host != nil {
                return ClipboardItem(
                    id: UUID().uuidString,
                    content: string,
                    type: .url,
                    sourceAppName: appName,
                    sourceBundleID: bundleID,
                    timestamp: Date(),
                    characterCount: string.count
                )
            }
            return ClipboardItem(
                id: UUID().uuidString,
                content: string,
                type: .text,
                sourceAppName: appName,
                sourceBundleID: bundleID,
                timestamp: Date(),
                characterCount: string.count
            )
        }

        if let rtfData = pasteboard.data(forType: .rtf) {
            let attr = try? NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            let plain = attr?.string ?? ""
            if !plain.isEmpty {
                return ClipboardItem(
                    id: UUID().uuidString,
                    content: plain,
                    type: .rtf,
                    sourceAppName: appName,
                    sourceBundleID: bundleID,
                    timestamp: Date(),
                    characterCount: plain.count
                )
            }
        }

        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            let size = image.size
            let px = Int(max(size.width, size.height))
            return ClipboardItem(
                id: UUID().uuidString,
                content: "Image",
                type: .image,
                sourceAppName: appName,
                sourceBundleID: bundleID,
                timestamp: Date(),
                characterCount: px
            )
        }

        return nil
    }

    // MARK: - Actions

    func pasteToClipboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        switch item.type {
        case .text, .rtf, .url:
            pasteboard.setString(item.content, forType: .string)
        case .file:
            if FileManager.default.fileExists(atPath: item.content) {
                pasteboard.writeObjects([URL(fileURLWithPath: item.content) as NSURL])
            }
        case .image:
            pasteboard.setString(item.content, forType: .string)
        }
    }

    func deleteItem(_ item: ClipboardItem) {
        itemsLock.lock()
        items.removeAll { $0.id == item.id }
        itemsLock.unlock()
        saveToDisk()
    }

    func clearAll() {
        itemsLock.lock()
        items.removeAll()
        itemsLock.unlock()
        saveToDisk()
    }

    func search(query: String) -> [ClipboardItem] {
        let lower = query.lowercased()
        return items.filter {
            $0.content.lowercased().contains(lower) ||
            $0.sourceAppName.lowercased().contains(lower) ||
            $0.type.rawValue.lowercased().contains(lower)
        }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        itemsLock.lock()
        let toSave = items.prefix(maxItems)
        itemsLock.unlock()

        if let data = try? JSONEncoder().encode(Array(toSave)) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        items = decoded.prefix(maxItems).map { $0 }
    }
}
