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
        // Capture source app from background queue — safe, won't block UI
        let frontmost = NSWorkspace.shared.frontmostApplication
        let appName = frontmost?.localizedName ?? "Unknown"
        let bundleID = frontmost?.bundleIdentifier ?? ""

        if let filePaths = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = filePaths.first {
            return ClipboardItem(
                id: UUID().uuidString,
                content: first.path,
                type: .file,
                smartType: .filePath,
                smartInfo: nil,
                sourceAppName: appName,
                sourceBundleID: bundleID,
                timestamp: Date(),
                characterCount: first.path.count
            )
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            let baseType: ClipboardContentType
            if let url = URL(string: string.trimmingCharacters(in: .whitespaces)),
               url.scheme != nil, url.host != nil {
                baseType = .url
            } else {
                baseType = .text
            }
            let smart = SmartClipboardService.analyze(content: string, baseType: baseType)

            return ClipboardItem(
                id: UUID().uuidString,
                content: string,
                type: baseType,
                smartType: smart.type,
                smartInfo: smart,
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
                let smart = SmartClipboardService.analyze(content: plain, baseType: .rtf)
                return ClipboardItem(
                    id: UUID().uuidString,
                    content: plain,
                    type: .rtf,
                    smartType: smart.type,
                    smartInfo: smart,
                    sourceAppName: appName,
                    sourceBundleID: bundleID,
                    timestamp: Date(),
                    characterCount: plain.count
                )
            }
        }

        // Try multiple image pasteboard types — readObjects(NSImage) doesn't work in background
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png, .init("public.jpeg"), .init("public.image")]
        for imgType in imageTypes {
            if let data = pasteboard.data(forType: imgType),
               let image = NSImage(data: data) {
                let size = image.size
                let px = Int(max(size.width, size.height))
                // Persist image to app support for preview
                let imagePath = persistImageData(data, ext: imgType == .tiff ? "tiff" : (imgType == .png ? "png" : "jpg"))
                return ClipboardItem(
                    id: UUID().uuidString,
                    content: imagePath ?? "Image",
                    type: .image,
                    smartType: .plainText,
                    smartInfo: nil,
                    sourceAppName: appName,
                    sourceBundleID: bundleID,
                    timestamp: Date(),
                    characterCount: px
                )
            }
        }

        return nil
    }

    private func persistImageData(_ data: Data, ext: String) -> String? {
        let fm = FileManager.default
        guard let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Snything", isDirectory: true) else { return nil }
        try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let filename = "clipboard_\(UUID().uuidString).\(ext)"
        let url = supportDir.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url.path
        } catch {
            return nil
        }
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
