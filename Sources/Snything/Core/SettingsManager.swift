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

    // Tab shortcut chord keys (after Cmd+Space prefix)
    @AppStorage("snything.tabShortcutFiles") var tabShortcutFiles: Int = 49 { // Space = chord trigger → Files
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.tabShortcutApplications") var tabShortcutApplications: Int = 0 { // A
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.tabShortcutClipboard") var tabShortcutClipboard: Int = 8 { // C
        didSet { objectWillChange.send() }
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
        // Sync launch at login on init
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
        scopesString = "/Applications,/Users,/opt,/usr/local,Library"
    }

    var debounceNanoseconds: UInt64 {
        UInt64(searchDelay * 1_000_000)
    }

    var maxResultsInt: Int {
        Int(maxResults)
    }
}
