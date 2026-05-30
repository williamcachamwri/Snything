import Foundation
import AppKit
import Sparkle

final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    @Published var isChecking = false
    @Published var showAlert = false
    @Published var alertVersion: String = ""
    @Published var alertReleaseNotes: String = ""
    @Published var statusMessage: String?

    private var updaterController: SPUStandardUpdaterController!
    private var isStarted = false

    private override init() {
        super.init()

        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        updaterController.updater.automaticallyChecksForUpdates = false
        updaterController.updater.automaticallyDownloadsUpdates = false

        // Try to start updater immediately
        do {
            try updaterController.startUpdater()
            isStarted = true
            print("[Sparkle] Updater started successfully")
        } catch {
            print("[Sparkle] Failed to start updater: \(error)")
            print("[Sparkle] This is expected in SPM debug mode (no .app bundle)")
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

    /// Check for updates. If `showAnyway` is true, always show UI even if no update.
    func checkForUpdates(showAnyway: Bool = false) {
        guard !isChecking else { return }

        guard isStarted else {
            statusMessage = "Updates unavailable in debug mode. Build the .app bundle for Sparkle updates."
            showAlert = true
            alertVersion = "N/A"
            alertReleaseNotes = "Sparkle updater requires a proper .app bundle.\n\nIn SPM debug builds, automatic updates are disabled.\nBuild with `.github/build_app.sh` to enable Sparkle."
            ChangelogWindowController.shared.showAnimated()
            return
        }

        isChecking = true
        statusMessage = nil

        if showAnyway {
            updaterController.checkForUpdates(nil)
        } else {
            updaterController.updater.checkForUpdatesInBackground()
        }
    }

    func installUpdate() {
        guard isStarted else { return }
        updaterController.checkForUpdates(nil)
    }

    func skipUpdate() {
        // Sparkle manages skip logic internally via user preferences
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
            self?.alertVersion = item.displayVersionString
            self?.alertReleaseNotes = item.itemDescription ?? ""
            self?.showAlert = true
            self?.statusMessage = "Update available: v\(item.displayVersionString)"
            ChangelogWindowController.shared.showAnimated()
        }
    }

    func updater(
        _ updater: SPUUpdater,
        didNotFindUpdate error: Error
    ) {
        DispatchQueue.main.async { [weak self] in
            let nsError = error as NSError
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
        willInstallUpdate item: SUAppcastItem
    ) {
        statusMessage = "Installing v\(item.displayVersionString)..."
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        statusMessage = "Relaunching..."
    }
}
