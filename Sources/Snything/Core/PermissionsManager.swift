import Foundation
import AppKit
import ApplicationServices

final class PermissionsManager: ObservableObject {
    @Published var hasFullDiskAccess: Bool = false
    @Published var hasAccessibility: Bool = false

    init() {
        refresh()
    }

    func refresh() {
        hasFullDiskAccess = checkFullDiskAccess()
        hasAccessibility = checkAccessibility()
    }

    func checkFullDiskAccess() -> Bool {
        let protectedURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/History.db")
        if FileManager.default.fileExists(atPath: protectedURL.path) {
            if (try? Data(contentsOf: protectedURL, options: .mappedIfSafe)) != nil {
                return true
            }
        }
        let fallbackURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mail")
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            if let _ = try? FileManager.default.contentsOfDirectory(atPath: fallbackURL.path) {
                return true
            }
        }
        return false
    }

    func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func openPrivacySettings(anchor: String) {
        var urlComponents = URLComponents(string: "x-apple.systempreferences:com.apple.preference.security")!
        urlComponents.queryItems = [URLQueryItem(name: "Privacy", value: anchor)]
        NSWorkspace.shared.open(urlComponents.url!)
    }

    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openSpotlightShortcutSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts")!
        NSWorkspace.shared.open(url)
    }
}
