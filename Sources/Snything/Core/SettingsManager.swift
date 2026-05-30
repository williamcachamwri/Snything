import Foundation
import SwiftUI
import ServiceManagement
import Carbon

final class SettingsManager: ObservableObject, @unchecked Sendable {
    static let shared = SettingsManager()

    @AppStorage("snything.searchDelay") var searchDelay: Double = 60 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.maxResults") var maxResults: Double = 500 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.showHiddenFiles") var showHiddenFiles: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.showPreviewOnSelect") var showPreviewOnSelect: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.launchAtLogin") var launchAtLogin: Bool = false {
        didSet {
            objectWillChange.send()
            syncLaunchAtLogin()
        }
    }
    @AppStorage("snything.autoCheckUpdates") var autoCheckUpdates: Bool = true {
        didSet { objectWillChange.send() }
    }

    // Hotkey config
    @AppStorage("snything.hotkeyKeyCode") var hotkeyKeyCode: Int = 49 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.hotkeyCmd") var hotkeyCmd: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.hotkeyShift") var hotkeyShift: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.hotkeyOption") var hotkeyOption: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.hotkeyCtrl") var hotkeyCtrl: Bool = false {
        didSet { objectWillChange.send() }
    }

    // Tab shortcut chord sequences (1-3 keys after global hotkey prefix)
    @AppStorage("snything.tabShortcutApplicationsJSON") var tabShortcutApplicationsJSON: String = "[0]" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.tabShortcutClipboardJSON") var tabShortcutClipboardJSON: String = "[8]" {
        didSet { objectWillChange.send() }
    }

    var tabShortcutApplications: [Int] {
        get {
            guard let data = tabShortcutApplicationsJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([Int].self, from: data) else { return [49, 0] }
            return arr
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                tabShortcutApplicationsJSON = str
            }
        }
    }

    var tabShortcutClipboard: [Int] {
        get {
            guard let data = tabShortcutClipboardJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([Int].self, from: data) else { return [49, 8] }
            return arr
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                tabShortcutClipboardJSON = str
            }
        }
    }

    var hotkeyModifiersUInt32: UInt32 {
        var mods: UInt32 = 0
        if hotkeyCmd { mods |= UInt32(cmdKey) }
        if hotkeyShift { mods |= UInt32(shiftKey) }
        if hotkeyOption { mods |= UInt32(optionKey) }
        if hotkeyCtrl { mods |= UInt32(controlKey) }
        return mods
    }

    // Scopes stored as comma-separated paths
    @AppStorage("snything.searchScopes") private var scopesString: String = "/Applications,/Users,/opt,/usr/local,Library"

    var searchScopes: [String] {
        get { scopesString.components(separatedBy: ",").filter { !$0.isEmpty } }
        set { scopesString = newValue.joined(separator: ",") }
    }

    private init() {
        syncLaunchAtLogin()
    }

    private func syncLaunchAtLogin() {
        let isRegistered = SMAppService.mainApp.status == .enabled
        if launchAtLogin && !isRegistered {
            try? SMAppService.mainApp.register()
        } else if !launchAtLogin && isRegistered {
            try? SMAppService.mainApp.unregister()
        }
    }

    func resetToDefaults() {
        searchDelay = 60
        maxResults = 500
        showHiddenFiles = false
        showPreviewOnSelect = false
        launchAtLogin = false
        hotkeyKeyCode = 49
        hotkeyCmd = true
        hotkeyShift = false
        hotkeyOption = false
        hotkeyCtrl = false
        tabShortcutApplicationsJSON = "[0]"
        tabShortcutClipboardJSON = "[8]"
        scopesString = "/Applications,/Users,/opt,/usr/local,Library"
    }

    var debounceNanoseconds: UInt64 {
        UInt64(searchDelay * 1_000_000)
    }

    var maxResultsInt: Int {
        Int(maxResults)
    }
}
