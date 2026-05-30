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

    // Window size
    @AppStorage("snything.windowWidth") var windowWidth: Double = 800 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.windowHeight") var windowHeight: Double = 520 {
        didSet { objectWillChange.send() }
    }

    // UI tuning
    @AppStorage("snything.animationSpeed") var animationSpeed: Double = 1.0 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.showFileIcons") var showFileIcons: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.maxRecents") var maxRecents: Double = 20 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.fontSizeScale") var fontSizeScale: Double = 1.0 {
        didSet { objectWillChange.send() }
    }

    // Hotkey config
    @AppStorage("snything.hotkeyKeyCode") var hotkeyKeyCode: Int = 49 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.hotkeyCmd") var hotkeyCmd: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.hotkeyShift") var hotkeyShift: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.hotkeyOption") var hotkeyOption: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.hotkeyCtrl") var hotkeyCtrl: Bool = false {
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
        windowWidth = 800
        windowHeight = 520
        animationSpeed = 1.0
        showFileIcons = true
        maxRecents = 20
        fontSizeScale = 1.0
        hotkeyKeyCode = 49
        hotkeyCmd = true
        hotkeyShift = true
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

    var maxRecentsInt: Int {
        Int(maxRecents)
    }
}
