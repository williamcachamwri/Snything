import Foundation
import AppKit

final class ClipboardManager {
    static let shared = ClipboardManager()

    private let maxItems = 100
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = -1
    private var timer: Timer?
    private let queue = DispatchQueue(label: "snything.clipboard", qos: .utility)
    private let itemsLock = NSLock()
    private let storageKey = "snything.clipboardHistory"

    private var _items: [ClipboardItem] = []
    var items: [ClipboardItem] {
        itemsLock.lock()
        defer { itemsLock.unlock() }
        return _items
    }

    private init() {
        loadFromDisk()
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Monitoring (background queue)

    private func startMonitoring() {
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                self?.queue.async { self?.checkClipboard() }
            }
        }
    }

    private func checkClipboard() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let newItem = captureItem() else { return }

        itemsLock.lock()
        defer { itemsLock.unlock() }

        if let first = _items.first, first.content == newItem.content, first.type == newItem.type {
            return
        }

        _items.insert(newItem, at: 0)
        if _items.count > maxItems {
            _items = Array(_items.prefix(maxItems))
        }

        // Persist on background after mutation
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.saveToDisk()
        }
    }

    // MARK: - Capture

    private func captureItem() -> ClipboardItem? {
        if let filePaths = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = filePaths.first {
            return ClipboardItem(
                id: UUID().uuidString,
                content: first.path,
                type: .file,
                timestamp: Date(),
                characterCount: first.path.count
            )
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            if let url = URL(string: string.trimmingCharacters(in: .whitespaces)),
               url.scheme != nil, url.host != nil {
                return ClipboardItem(
                    id: UUID().uuidString,
                    content: string,
                    type: .url,
                    timestamp: Date(),
                    characterCount: string.count
                )
            }
            return ClipboardItem(
                id: UUID().uuidString,
                content: string,
                type: .text,
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
        _items.removeAll { $0.id == item.id }
        itemsLock.unlock()
        saveToDisk()
    }

    func clearAll() {
        itemsLock.lock()
        _items.removeAll()
        itemsLock.unlock()
        saveToDisk()
    }

    // MARK: - Persistence

    private func saveToDisk() {
        itemsLock.lock()
        let toSave = Array(_items.prefix(maxItems))
        itemsLock.unlock()

        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        itemsLock.lock()
        _items = decoded.prefix(maxItems).map { $0 }
        itemsLock.unlock()
    }
}
