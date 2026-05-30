import Foundation
import AppKit
import Sparkle

final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    @Published var isChecking = false
    @Published var statusMessage: String?

    private(set) var controller: SPUStandardUpdaterController!
    private var isStarted = false

    var updater: SPUUpdater {
        controller.updater
    }

    private override init() {
        super.init()

        // Sparkle requires a valid .app bundle with CFBundleIdentifier and CFBundleVersion.
        guard Bundle.main.bundleIdentifier != nil,
              Bundle.main.infoDictionary?["CFBundleVersion"] != nil else {
            print("[Sparkle] Bundle missing CFBundleIdentifier or CFBundleVersion — updater disabled")
            print("[Sparkle] Build .app bundle with .github/build_app.sh to enable updates")
            isStarted = false
            return
        }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        controller.updater.automaticallyChecksForUpdates = false
        controller.updater.automaticallyDownloadsUpdates = false

        print("[Sparkle] Updater initialized")
        isStarted = true
    }

    // MARK: - Public API

    func startAutomaticChecks() {
        guard isStarted else {
            print("[Sparkle] Updater not started — skipping automatic checks")
            return
        }
        controller.updater.automaticallyChecksForUpdates = SettingsManager.shared.autoCheckUpdates
        controller.updater.updateCheckInterval = 24 * 60 * 60
    }

    /// Check for updates. Sparkle shows its own native UI.
    func checkForUpdates() {
        guard isStarted else {
            let alert = NSAlert()
            alert.messageText = "Updates Unavailable"
            alert.informativeText = "Automatic updates require a signed .app bundle installed to /Applications/.\n\nBuild with `.github/build_app.sh` to enable Sparkle updates."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        isChecking = true
        statusMessage = nil
        controller.checkForUpdates(nil)
    }

    func installUpdate() {
        guard isStarted else { return }
        controller.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        let count = appcast.items.count
        print("[Sparkle] Appcast loaded: \(count) item(s)")
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString ?? "?"
        let build = item.versionString ?? "?"
        print("[Sparkle] Update available: v\(version) (build \(build))")
        statusMessage = "Update available: v\(version)"
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let nsError = error as NSError
        print("[Sparkle] No update found: \(nsError.localizedDescription) [code=\(nsError.code), domain=\(nsError.domain)]")
        if nsError.domain == "SPUErrorDomain" && nsError.code == 1001 {
            statusMessage = "You're on the latest version."
        } else {
            statusMessage = "Update check failed: \(nsError.localizedDescription)"
        }
        isChecking = false
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        let version = item.displayVersionString ?? "?"
        print("[Sparkle] Downloaded update: v\(version)")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        let version = item.displayVersionString ?? "?"
        print("[Sparkle] Installing update: v\(version)")
        statusMessage = "Installing v\(version)..."
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        print("[Sparkle] Relaunching application...")
        statusMessage = "Relaunching..."
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        let nsError = error as NSError
        print("[Sparkle] Update aborted: \(nsError.localizedDescription) [code=\(nsError.code), domain=\(nsError.domain)]")
        statusMessage = "Update aborted: \(nsError.localizedDescription)"
        isChecking = false
    }
}
