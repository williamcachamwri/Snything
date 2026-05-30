import Foundation
import CoreServices

/// Watches the filesystem for deletions using FSEvents and broadcasts
/// notifications so the UI can refresh in real time.
final class FileSystemMonitor {
    static let shared = FileSystemMonitor()

    private var stream: FSEventStreamRef?
    private var debounceTimer: Timer?

    private init() {}

    func start() {
        stop()

        let pathsToWatch = [
            NSHomeDirectory(),
            "/Applications",
            "/System/Applications",
            "/Users"
        ]

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, eventFlags, _ in
            guard let clientCallBackInfo else { return }
            let watcher = Unmanaged<FileSystemMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            watcher.handleEvents(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags)
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let cfPaths = pathsToWatch as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            flags
        )

        guard let stream = stream else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    private func handleEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>) {
        _ = eventPaths.assumingMemoryBound(to: CFArray.self).pointee as? [String]

        var hasDeletions = false
        for i in 0..<numEvents {
            let flags = eventFlags[i]
            let isRemoved = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0
            let isRenamed = (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)) != 0
            if isRemoved || isRenamed {
                hasDeletions = true
                break
            }
        }

        guard hasDeletions else { return }

        // Debounce: many events fire in a burst
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            NotificationCenter.default.post(name: .fileSystemChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let fileSystemChanged = Notification.Name("snything.filesystemChanged")
}
