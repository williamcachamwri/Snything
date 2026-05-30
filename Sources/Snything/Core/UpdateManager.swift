import Foundation
import AppKit
import Sparkle

final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    @Published var isChecking = false
    @Published var statusMessage: String?

    private var updaterController: SPUStandardUpdaterController!
    private var isStarted = false

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

        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        updaterController.updater.automaticallyChecksForUpdates = false
        updaterController.updater.automaticallyDownloadsUpdates = false

        do {
            try updaterController.startUpdater()
            isStarted = true
            print("[Sparkle] Updater started successfully")
        } catch {
            print("[Sparkle] Failed to start updater: \(error)")
            isStarted = false
        }
    }

    // MARK: - Public API

    func startAutomaticChecks() {
        guard isStarted else {
            print("[Sparkle] Updater not started — skipping automatic checks")
            return
        }
        updaterController.updater.automaticallyChecksForUpdates = SettingsManager.shared.autoCheckUpdates
        updaterController.updater.updateCheckInterval = 24 * 60 * 60
    }

    /// Check for updates. Sparkle shows its own native UI.
    func checkForUpdates(showAnyway: Bool = false) {
        guard !isChecking else { return }

        guard isStarted else {
            // In debug mode (swift run), show native alert instead of custom window
            let alert = NSAlert()
            alert.messageText = "Updates Unavailable"
            alert.informativeText = "Automatic updates require a signed .app bundle.\n\nBuild with `.github/build_app.sh` and install to /Applications/ to enable Sparkle updates."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        isChecking = true
        statusMessage = nil
        updaterController.checkForUpdates(nil)
    }

    func installUpdate() {
        guard isStarted else { return }
        updaterController.checkForUpdates(nil)
    }

    func skipUpdate() {
        // Sparkle manages skip logic internally
    }

    // MARK: - SPUUpdaterDelegate

    func feedURLString(for updater: SPUUpdater) -> String? {
        VersionManager.shared.appcastURL.absoluteString
    }

    func updater(
        _ updater: SPUUpdater,
        mayPerform updateCheck: SPUUpdateCheck
    ) throws -> Bool {
        true
    }

    func updater(
        _ updater: SPUUpdater,
        didFindValidUpdate item: SUAppcastItem
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.statusMessage = "Update available: v\(item.displayVersionString)"
            // Sparkle's SPUStandardUserDriver handles the UI automatically
        }
    }

    func updater(
        _ updater: SPUUpdater,
        didNotFindUpdate error: Error
    ) {
        DispatchQueue.main.async { [weak self] in
            let nsError = error as NSError
            print("[Sparkle] didNotFindUpdate: domain=\(nsError.domain) code=\(nsError.code)")
            if nsError.domain == "SPUErrorDomain" && nsError.code == 1001 {
                self?.statusMessage = "You're on the latest version."
            } else {
                self?.statusMessage = "Update check failed: \(error.localizedDescription)"
            }
            self?.isChecking = false
        }
    }

    func updater(
        _ updater: SPUUpdater,
        failedToDownloadUpdate item: SUAppcastItem,
        error: Error
    ) {
        print("[Sparkle] failedToDownloadUpdate: \(error)")
        statusMessage = "Download failed: \(error.localizedDescription)"
        isChecking = false
    }

    func updater(
        _ updater: SPUUpdater,
        willInstallUpdate item: SUAppcastItem
    ) {
        statusMessage = "Installing v\(item.displayVersionString)..."
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        statusMessage = "Relaunching..."
    }
}
