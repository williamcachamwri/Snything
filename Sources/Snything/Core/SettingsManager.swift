import Foundation
import SwiftUI
import ServiceManagement

final class SettingsManager: ObservableObject, @unchecked Sendable {
    static let shared = SettingsManager()

    @AppStorage("snything.searchDelay") var searchDelay: Double = 60 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("snything.maxResults") var maxResults: Double = 200 {
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
        maxResults = 200
        showHiddenFiles = false
        showPreviewOnSelect = false
        launchAtLogin = false
        scopesString = "/Applications,/Users,/opt,/usr/local,Library"
    }

    var debounceNanoseconds: UInt64 {
        UInt64(searchDelay * 1_000_000)
    }

    var maxResultsInt: Int {
        Int(maxResults)
    }
}
