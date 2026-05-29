import Foundation
import AppKit
import SwiftUI

final class KeyboardManager: ObservableObject {
    static let shared = KeyboardManager()

    var onKeyDown: ((NSEvent) -> Bool)?

    private var localMonitor: Any?

    func startMonitoring() {
        stopMonitoring()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.onKeyDown?(event) == true {
                return nil
            }
            return event
        }
    }

    func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
