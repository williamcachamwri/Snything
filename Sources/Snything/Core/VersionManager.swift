import Foundation

/// Custom semantic version format: {Major}.{Minor}.{Patch}
///   Major: 1+, increments when Minor exceeds 20
///   Minor: 0-20, resets to 0 when it exceeds 20
///   Patch: 0-100, increments Minor when it exceeds 100
///
/// Example cycle:
///   1.0.0 → 1.0.1 → ... → 1.0.100 → 1.1.0 → ... → 1.20.100 → 2.0.0
struct SnyVersion: Equatable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = max(1, major)
        self.minor = max(0, min(20, minor))
        self.patch = max(0, min(100, patch))
    }

    init?(from string: String) {
        let parts = string.split(separator: ".", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3,
              let major = Int(parts[0]), major >= 1,
              let minor = Int(parts[1]), minor >= 0, minor <= 20,
              let patch = Int(parts[2]), patch >= 0, patch <= 100 else {
            return nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    static func < (lhs: SnyVersion, rhs: SnyVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    /// Bump patch. If patch exceeds 100, bump minor and reset patch.
    /// If minor exceeds 20, bump major and reset minor.
    func bumpPatch() -> SnyVersion {
        var newPatch = patch + 1
        var newMinor = minor
        var newMajor = major

        if newPatch > 100 {
            newPatch = 0
            newMinor += 1
        }
        if newMinor > 20 {
            newMinor = 0
            newMajor += 1
        }
        return SnyVersion(major: newMajor, minor: newMinor, patch: newPatch)
    }

    /// Bump minor. If minor exceeds 20, bump major and reset minor.
    func bumpMinor() -> SnyVersion {
        var newMinor = minor + 1
        var newMajor = major
        if newMinor > 20 {
            newMinor = 0
            newMajor += 1
        }
        return SnyVersion(major: newMajor, minor: newMinor, patch: 0)
    }

    /// Bump major, reset minor and patch.
    func bumpMajor() -> SnyVersion {
        SnyVersion(major: major + 1, minor: 0, patch: 0)
    }
}

/// Central version management for Snything.
final class VersionManager {
    static let shared = VersionManager()

    /// The current app version. Reads from Info.plist at runtime.
    var currentVersion: SnyVersion {
        let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "1.0.0"
        return SnyVersion(from: versionString) ?? SnyVersion(major: 1, minor: 0, patch: 0)
    }

    /// The appcast URL for Sparkle update checks.
    let appcastURL = URL(string: "https://williamcachamwri.github.io/Snything/appcast.xml")!

    private init() {}

    /// Compare a remote version against the current installed version.
    func isNewer(than remoteVersionString: String) -> Bool {
        guard let remote = SnyVersion(from: remoteVersionString) else { return false }
        return remote > currentVersion
    }

    /// Format a version string for display.
    func displayString(for versionString: String) -> String {
        guard let version = SnyVersion(from: versionString) else { return versionString }
        return "v\(version)"
    }
}
