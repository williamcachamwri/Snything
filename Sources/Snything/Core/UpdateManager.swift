import Foundation
import AppKit
import SwiftUI

final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var isChecking = false
    @Published var showAlert = false
    @Published var alertVersion: String = ""
    @Published var alertReleaseNotes: String = ""
    @Published var downloadURL: URL?
    @Published var statusMessage: String?

    private let repoAPI = "https://api.github.com/repos/williamcachamwri/Snything/releases/latest"
    private let releasesPage = "https://github.com/williamcachamwri/Snything/releases/latest"
    private let lastPromptedTagKey = "snything.lastPromptedReleaseTag"

    private init() {}

    // MARK: - Public API

    func checkForUpdates(showAnyway: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        showAlert = false
        statusMessage = nil

        guard let url = URL(string: repoAPI) else {
            finishCheck()
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.statusMessage = "Update check failed: \(error.localizedDescription)"
                    self.finishCheck()
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.finishCheck()
                    return
                }

                let lastPrompted = UserDefaults.standard.string(forKey: self.lastPromptedTagKey)
                if !showAnyway, tagName == lastPrompted {
                    self.finishCheck()
                    return
                }

                self.findDMGAsset(in: json)

                let version = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                self.alertVersion = version
                self.alertReleaseNotes = json["body"] as? String ?? ""
                self.showAlert = true

                UserDefaults.standard.set(tagName, forKey: self.lastPromptedTagKey)

                self.finishCheck()

                // Show independent modal window — not tied to search panel
                ChangelogWindowController.shared.showAnimated()
            }
        }.resume()
    }

    func installUpdate() {
        guard let downloadURL = downloadURL else {
            NSWorkspace.shared.open(URL(string: releasesPage)!)
            return
        }

        statusMessage = "Downloading update..."
        ChangelogWindowController.shared.dismissAnimated()

        let tempDir = FileManager.default.temporaryDirectory
        let dmgPath = tempDir.appendingPathComponent("Snything-Update.dmg")
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

    func skipUpdate() {
        showAlert = false
        ChangelogWindowController.shared.dismissAnimated()
    }

    // MARK: - Private

    private func finishCheck() {
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
        downloadURL = nil
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

        do {
            if FileManager.default.fileExists(atPath: targetApp.path) {
                try FileManager.default.removeItem(at: targetApp)
            }
            try FileManager.default.copyItem(at: sourceApp, to: targetApp)
        } catch {
            statusMessage = "Failed to install: \(error.localizedDescription)"
            detach(mountPoint: volPath)
            return
        }

        detach(mountPoint: volPath)
        try? FileManager.default.removeItem(at: dmgPath)

        statusMessage = "Update installed. Relaunching..."
        let relaunchTask = Process()
        relaunchTask.executableURL = URL(fileURLWithPath: "/bin/bash")
        relaunchTask.arguments = ["-c", "sleep 1; open -a /Applications/Snything.app"]
        try? relaunchTask.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    private func detach(mountPoint: String) {
        let detachProcess = Process()
        detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        detachProcess.arguments = ["detach", mountPoint]
        try? detachProcess.run()
    }
}
