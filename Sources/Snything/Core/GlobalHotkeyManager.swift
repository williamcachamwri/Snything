import Foundation
import Carbon
import AppKit

final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    private init() {}

    func registerDefaultShortcut(callback: @escaping () -> Void) {
        self.callback = callback

        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: fourCharCode("SNYT"), id: 1)

        let keyCode = UInt32(kVK_Space)
        let modifiers = UInt32(cmdKey)

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            print("Failed to register global hotkey: \(status)")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private let hotKeyCallback: EventHandlerUPP = { (_, event, userData) -> OSStatus in
        guard let userData = userData else { return OSStatus(eventNotHandledErr) }
        let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

        var hkID = EventHotKeyID()
        let size = MemoryLayout<EventHotKeyID>.size
        let err = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            size,
            nil,
            &hkID
        )

        guard err == noErr else { return OSStatus(eventNotHandledErr) }

        if hkID.id == 1 {
            DispatchQueue.main.async {
                manager.callback?()
            }
            return noErr
        }

        return OSStatus(eventNotHandledErr)
    }
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    if let data = string.data(using: .macOSRoman) {
        for byte in data.prefix(4) {
            result = (result << 8) + FourCharCode(byte)
        }
    }
    return result
}
