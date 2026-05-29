import Foundation
import AppKit

final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var isChecking = false
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var downloadURL: URL?
    @Published var statusMessage: String?

    private let currentVersion = "1.0.0"
    private let repoAPI = "https://api.github.com/repos/williamcachamwri/Snything/releases/latest"
    private let releasesPage = "https://github.com/williamcachamwri/Snything/releases/latest"

    private init() {}

    // MARK: - Public API

    func checkForUpdates(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        updateAvailable = false
        statusMessage = silent ? nil : "Checking for updates..."

        guard let url = URL(string: repoAPI) else {
            finishCheck(silent: silent, available: false)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.statusMessage = silent ? nil : "Update check failed: \(error.localizedDescription)"
                    self.finishCheck(silent: silent, available: false)
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.finishCheck(silent: silent, available: false)
                    return
                }

                let remoteVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                let isNewer = self.isVersion(remoteVersion, newerThan: self.currentVersion)

                if isNewer {
                    self.latestVersion = remoteVersion
                    self.findDMGAsset(in: json)
                    self.updateAvailable = true
                    self.statusMessage = "Update available: v\(remoteVersion)"
                    if !silent {
                        self.showUpdateAlert(version: remoteVersion)
                    }
                } else {
                    self.statusMessage = silent ? nil : "Snything is up to date."
                }

                self.finishCheck(silent: silent, available: isNewer)
            }
        }.resume()
    }

    func installUpdate() {
        guard let downloadURL = downloadURL else {
            NSWorkspace.shared.open(URL(string: releasesPage)!)
            return
        }

        statusMessage = "Downloading update..."
        let tempDir = FileManager.default.temporaryDirectory
        let dmgPath = tempDir.appendingPathComponent("Snything-Update.dmg")

        // Remove old DMG if exists
        try? FileManager.default.removeItem(at: dmgPath)

        let task = URLSession.shared.downloadTask(with: downloadURL) { [weak self] localURL, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.statusMessage = "Download failed: \(error.localizedDescription)"
                    return
                }

                guard let localURL = localURL else {
                    self.statusMessage = "Download failed."
                    return
                }

                do {
                    try FileManager.default.moveItem(at: localURL, to: dmgPath)
                    self.mountAndInstall(dmgPath: dmgPath)
                } catch {
                    self.statusMessage = "Failed to prepare update: \(error.localizedDescription)"
                }
            }
        }
        task.resume()
    }

    // MARK: - Private

    private func finishCheck(silent: Bool, available: Bool) {
        isChecking = false
    }

    private func findDMGAsset(in json: [String: Any]) {
        guard let assets = json["assets"] as? [[String: Any]] else { return }
        for asset in assets {
            if let name = asset["name"] as? String,
               name.hasSuffix(".dmg"),
               let urlString = asset["browser_download_url"] as? String,
               let url = URL(string: urlString) {
                downloadURL = url
                return
            }
        }
        // Fallback: no DMG asset found, open releases page
        downloadURL = nil
    }

    private func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    private func showUpdateAlert(version: String) {
        let alert = NSAlert()
        alert.messageText = "Snything v\(version) is available"
        alert.informativeText = "A new version of Snything has been released. Would you like to download and install it now?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "View Release")

        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow else { return }
            alert.beginSheetModal(for: window) { [weak self] response in
                guard let self = self else { return }
                switch response {
                case .alertFirstButtonReturn:
                    self.installUpdate()
                case .alertThirdButtonReturn:
                    NSWorkspace.shared.open(URL(string: self.releasesPage)!)
                default:
                    break
                }
            }
        }
    }

    private func mountAndInstall(dmgPath: URL) {
        statusMessage = "Installing update..."

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgPath.path, "-nobrowse", "-noverify"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            statusMessage = "Failed to mount update: \(error.localizedDescription)"
            return
        }

        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            statusMessage = "Failed to read mounted volume."
            return
        }

        // Parse mount point from hdiutil output
        let lines = output.components(separatedBy: .newlines)
        var mountPoint: String?
        for line in lines {
            let parts = line.components(separatedBy: "\t")
            if parts.count >= 3, parts[2].hasPrefix("/Volumes/") {
                mountPoint = parts[2].trimmingCharacters(in: .whitespaces)
                break
            }
        }

        guard let volPath = mountPoint else {
            statusMessage = "Could not find mounted DMG."
            return
        }

        let sourceApp = URL(fileURLWithPath: volPath).appendingPathComponent("Snything.app")
        let targetApp = URL(fileURLWithPath: "/Applications/Snything.app")

        // Replace app in /Applications
        do {
            if FileManager.default.fileExists(atPath: targetApp.path) {
                try FileManager.default.removeItem(at: targetApp)
            }
            try FileManager.default.copyItem(at: sourceApp, to: targetApp)
        } catch {
            statusMessage = "Failed to install: \(error.localizedDescription)"
            detach(dmgPath: dmgPath)
            return
        }

        // Eject DMG
        detach(dmgPath: dmgPath)
        try? FileManager.default.removeItem(at: dmgPath)

        // Relaunch
        statusMessage = "Update installed. Relaunching..."
        let relaunchTask = Process()
        relaunchTask.executableURL = URL(fileURLWithPath: "/bin/bash")
        relaunchTask.arguments = ["-c", "sleep 1; open -a /Applications/Snything.app"]
        try? relaunchTask.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    private func detach(dmgPath: URL) {
        let detachProcess = Process()
        detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        detachProcess.arguments = ["detach", dmgPath.path]
        try? detachProcess.run()
    }
}
