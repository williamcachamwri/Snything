<p align="center">
  <img src="Sources/Snything/Resources/AppIcon-transparent.png" width="128" height="128" alt="Snything App Icon" />
</p>

<h1 align="center">Snything</h1>

<p align="center">
  <b>A minimalist, blazing-fast native search utility for macOS.</b><br/>
  Built entirely with SwiftUI and native macOS frameworks. No Electron, no web views, just pure speed.
</p>

<p align="center">
  <a href="https://github.com/williamcachamwri/Snything/releases/latest">Latest Release</a>
  &nbsp;&bull;&nbsp;
  <a href="https://github.com/williamcachamwri/Snything/issues">Issues &amp; Support</a>
</p>

---

## Features

- **Dual Search Engines**: Combines macOS Spotlight (`mdfind` CLI) with parallel FileManager enumeration for comprehensive, instant results across your entire system.
- **Global Hotkey**: Invoke anywhere with a configurable global shortcut (default: Command+Space).
- **Quick Preview**: Press Space on any result to reveal a rich preview panel without leaving the search context.
  - **Folders**: Expandable tree structure with recursive file/directory counts and total size calculation. Displays Git branch and working tree status when inside a repository.
  - **Images**: High-performance thumbnail decoding (including RAW formats: CR2, CR3, NEF, ARW, RAF, DNG, ORF, RW2, PEF, X3F, and more) with embedded EXIF metadata display (camera model, lens, ISO, aperture, shutter speed, focal length, capture date, resolution).
  - **Code Files**: Syntax-highlighted preview with support for Swift, Python, JavaScript, TypeScript, C/C++, Go, Rust, Java, Kotlin, HTML, CSS, JSON, SQL, Shell, and more.
  - **Generic Files**: File kind, size, modification date, and parent directory at a glance.
- **Smart Scoring**: Results are ranked by exact match, prefix match, contains match, with bonuses for Applications and frequently-accessed paths.
- **Glassmorphism UI**: Translucent floating panel with spring physics, smooth animations, and a modern aesthetic that feels at home on macOS.
- **Keyboard-First Navigation**: Full arrow-key navigation with Enter to open and Space to preview. No mouse required.
- **Onboarding Flow**: Guided first-launch experience for permissions (Accessibility for global hotkey, Full Disk Access for complete search coverage).
- **Settings Panel**: Accessible from the menu bar. Configure search delay, result limits, search scopes, auto preview, hidden files, and launch at login.
- **Menu Bar Integration**: Lives in the status bar with magnifying glass icon. LSUIElement mode hides the Dock icon for a clean, utility-like feel.

## Architecture

```
Sources/Snything/
  Core/
    FastSearchEngine.swift      -- mdfind + parallel FS scan + aggressive NSCache
    SearchProvider.swift          -- SearchCoordinator with debounce and cancellation
    SearchResult.swift            -- Unified model with kind inference
    SettingsManager.swift           -- @AppStorage persistence for all user settings
    GlobalHotkeyManager.swift     -- Carbon Event Hot Keys for Command+Space
    KeyboardManager.swift         -- Global key-down monitor for arrow/enter/space/esc
    PermissionsManager.swift      -- Accessibility & Full Disk Access checks
  UI/
    SearchWindow.swift            -- NSPanel with CASpringAnimation open/close
    SearchView.swift              -- Two-column layout: results + inline preview
    ResultListView.swift          -- ScrollViewReader auto-scroll on selection
    ResultRowView.swift           -- File icon + name + path + Enter/Space badges
    PreviewView.swift             -- Folder tree / Image / Code / Generic previews
    SearchBarView.swift           -- Glassmorphism search input
    SettingsView.swift            -- General, Search Scopes, and About tabs
  Onboarding/
    OnboardingView.swift          -- Multi-step onboarding with glass cards
    SplashView.swift              -- Branded launch screen
  SnythingApp.swift               -- AppDelegate, menu bar, window lifecycle
```

## Building

Open `Package.swift` directly in Xcode, or build from the terminal:

```bash
swift build
swift test
```

To create a signed `.app` bundle:

```bash
.github/build_app.sh
```

The release bundle will be produced at `.build/Snything.app`.

To create a release DMG:

```bash
.github/create_dmg.sh
```

The DMG will be produced at `.build/Snything-Release.dmg`.

## First Launch (Downloaded DMG)

Because Snything is distributed without a paid Apple Developer ID certificate, macOS Gatekeeper will show a security warning on the first launch after downloading from GitHub.

**To open the app:**

1. Drag `Snything.app` from the DMG into `/Applications`.
2. **Right-click** (or Control-click) the app and select **Open**.
3. Click **Open** in the dialog. The app will launch normally from then on.

**Or use Terminal:**
```bash
xattr -dr com.apple.quarantine /Applications/Snything.app
open /Applications/Snything.app
```

## Requirements

- macOS 14.0+
- Xcode 15+ (for Swift 5.9)

## Search Scope

By default, Snything indexes and searches across:

- Home directory
- /Applications
- /System/Applications
- /Users
- /opt, /usr/local
- ~/Downloads, ~/Documents, ~/Desktop

You can customize scopes from the **Settings > Search** panel.

## Privacy & Permissions

Snything requires two macOS permissions to function fully:

1. **Accessibility**: Needed to register the global Command+Space hotkey via Carbon APIs.
2. **Full Disk Access**: Required to search inside protected system folders and user directories that are otherwise inaccessible to third-party apps.

No data leaves your machine. All indexing and search happen locally.
