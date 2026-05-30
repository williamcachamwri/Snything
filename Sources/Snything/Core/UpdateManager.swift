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

    private override init() {
        super.init()

        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        // Configure Sparkle updater
        updaterController.updater.automaticallyChecksForUpdates = SettingsManager.shared.autoCheckUpdates
        updaterController.updater.automaticallyDownloadsUpdates = false
        updaterController.updater.updateCheckInterval = 24 * 60 * 60 // daily
    }

    // MARK: - Public API

    func startAutomaticChecks() {
        updaterController.startUpdater()
    }

    /// Check for updates. If `showAnyway` is true, always show UI even if no update.
    func checkForUpdates(showAnyway: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        statusMessage = nil

        if showAnyway {
            updaterController.checkForUpdates(nil)
        } else {
            updaterController.updater.checkForUpdatesInBackground()
        }

        // Sparkle handles the UI; we just track the check state briefly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isChecking = false
        }
    }

    func installUpdate() {
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
