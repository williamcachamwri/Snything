<p align="center">
  <img src="Sources/Snything/Resources/AppIcon-transparent.png" width="128" height="128" alt="Snything App Icon" />
</p>

<h1 align="center">Snything</h1>

<p align="center">
  <b>A minimalist, blazing-fast native search utility for macOS.</b><br/>
  Built entirely with SwiftUI and native macOS frameworks. No Electron, no web views — just pure speed.
</p>

<p align="center">
  <a href="https://github.com/williamcachamwri/Snything/releases/latest">Latest Release</a>
  &nbsp;&bull;&nbsp;
  <a href="https://github.com/williamcachamwri/Snything/issues">Issues &amp; Support</a>
</p>

---

## Features

### Instant Search
Snything combines two powerful search engines to give you comprehensive results in milliseconds:

- **Spotlight Integration**: Uses the native `mdfind` CLI to leverage macOS's built-in Spotlight index.
- **Parallel FileSystem Scan**: Scans your home directory, `/Applications`, `/Users`, and more in parallel using `FileManager` enumerators.
- **Smart Scoring**: Exact matches rank highest, followed by prefix matches and contains matches. Applications and frequently-accessed paths receive bonus scores.
- **Debounced Input**: Configurable search delay (0-300ms) so results update smoothly as you type.

### Recent Files at a Glance
Open the search panel with an empty query and instantly see the **20 most recently modified files** from:

- `~/Downloads`
- `~/Desktop`
- `~/Documents`
- `~/Pictures`

Screenshots you just took, files you just downloaded, documents you just saved — they all appear automatically, sorted by modification time. The list refreshes live every 3 seconds while the panel is open, with seamless updates that don't flicker or re-animate existing rows.

### Drag & Drop Anywhere
Every search result is draggable. Simply **click and hold** on any file or folder, drag it out of the search panel, and drop it into:

- **Chat apps** (Messages, Telegram, Slack, WhatsApp)
- **Email clients** (Mail, Gmail in browser)
- **Finder folders**
- **Any app** that accepts file drops

The search window stays fixed in place during drag — it won't follow your cursor — so you can drag multiple files in sequence without the panel moving.

### Rich Quick Preview
Press **Space** on any selected result to reveal an inline preview panel without leaving the search context:

| File Type | Preview Content |
|-----------|-----------------|
| **Folders** | Expandable tree with recursive file/directory counts, total size, and Git branch status |
| **Images** | High-performance thumbnail with embedded EXIF metadata (camera model, lens, ISO, aperture, shutter speed, focal length, capture date, resolution). Supports RAW formats: CR2, CR3, NEF, ARW, RAF, DNG, ORF, RW2, PEF, X3F, and more |
| **Code Files** | Syntax-highlighted preview for Swift, Python, JavaScript, TypeScript, C/C++, Go, Rust, Java, Kotlin, HTML, CSS, JSON, SQL, Shell, and more |
| **Generic Files** | File kind, size, modification date, and parent directory at a glance |

### Keyboard-First Navigation
Never touch your mouse:

| Shortcut | Action |
|----------|--------|
| `⌘Space` | Toggle search window |
| `↑ / ↓` | Navigate results |
| `Enter` | Open selected file with default app |
| `⌘Enter` | Reveal selected file in Finder |
| `Space` | Toggle preview panel |
| `Esc` | Hide search window |
| `Any letter` | Start typing to search (auto-focuses search bar) |

### Glassmorphism UI
A translucent floating panel that feels at home on modern macOS:

- **NSVisualEffectView** with `.hudWindow` material
- **Spring physics** on open/close (CASpringAnimation)
- **Smooth animations** on selection, preview toggle, and result transitions
- **Asymmetric row transitions**: insertion slides up with fade + scale, removal fades out gently
- **Gradient borders** and subtle glow effects on selected items
- **Floating particle background** on onboarding and splash screens

### Menu Bar Integration
Lives quietly in your status bar with a magnifying glass icon. In LSUIElement mode, Snything hides from the Dock and Task Switcher for a clean, utility-like feel. Access Settings, Reset Onboarding, or Quit from the menu bar at any time.

### First-Launch Onboarding
A guided, multi-step onboarding experience:

- **Welcome screen** with animated logo, floating particles, and gradient orb
- **Permission requests** for Accessibility (global hotkey) and Full Disk Access (complete search coverage)
- **Click-outside-to-dismiss** — clicking anywhere outside the onboarding window dismisses it and proceeds
- **Dock icon visible** during onboarding, auto-hidden after setup completes
- **Launch at Login** option on the final completion screen

### Settings Panel
Accessible via the menu bar, organized into three tabs:

| Tab | Options |
|-----|---------|
| **General** | Show Hidden Files, Auto Preview, Launch at Login, Search Delay slider, Max Results slider |
| **Search** | Selectable search scopes (Home, Applications, System Applications, All Users, System Library, Opt, Local) |
| **About** | App version, GitHub repo link, Support (Issues), Report Issue |

All settings persist via `@AppStorage` and take effect immediately:
- **Search Delay** — live debounce adjustment
- **Max Results** — live result limit
- **Show Hidden Files** — includes dot-prefixed files in filesystem scan
- **Auto Preview** — preview panel opens automatically on arrow-key selection
- **Search Scopes** — checked directories are included in the parallel scan

---

## Installation

### Download DMG (Recommended)
1. Go to [Releases](https://github.com/williamcachamwri/Snything/releases/latest) and download `Snything-Release.dmg`
2. Open the DMG and drag `Snything.app` into `/Applications`
3. **Right-click** the app and select **Open** (required on first launch due to ad-hoc signing)

> **Note**: Because Snything is distributed without a paid Apple Developer ID certificate, macOS Gatekeeper will show a security warning on the first launch. Right-click → Open bypasses this permanently.

### Build from Source
```bash
git clone https://github.com/williamcachamwri/Snything.git
cd Snything
swift build -c release
.github/build_app.sh
open .build/Snything.app
```

---

## Requirements

- macOS 14.0+
- Xcode 15+ (for Swift 5.9)

---

## Permissions

Snything requires two macOS permissions to function fully:

1. **Accessibility**: Needed to register the global `⌘Space` hotkey via Carbon Event APIs.
2. **Full Disk Access**: Required to search inside protected system folders and user directories that are otherwise inaccessible to third-party apps.

No data leaves your machine. All indexing and search happen locally.

---

## Architecture

```
Sources/Snything/
  Core/
    FastSearchEngine.swift      -- mdfind + parallel FS scan + aggressive NSCache
    SearchProvider.swift          -- SearchCoordinator with debounce, cancellation, and preview logic
    SearchResult.swift            -- Unified model with file-kind inference
    SettingsManager.swift         -- @AppStorage persistence for all user settings
    RecentFilesManager.swift      -- Live filesystem scan of Downloads/Desktop/Documents/Pictures
    GlobalHotkeyManager.swift     -- Carbon Event Hot Keys for Command+Space
    KeyboardManager.swift         -- Global key-down monitor for arrow/enter/space/escape
    PermissionsManager.swift      -- Accessibility & Full Disk Access checks
  UI/
    SearchWindow.swift            -- NSPanel with CASpringAnimation open/close
    SearchView.swift              -- Two-column layout: results + inline preview
    ResultListView.swift          -- ScrollViewReader auto-scroll on keyboard selection
    ResultRowView.swift           -- File icon + name + path + Drag/Open/Preview badges
    PreviewView.swift             -- Folder tree / Image / Code / Generic previews
    SearchBarView.swift           -- Glassmorphism search input with focus glow
    SettingsView.swift            -- General, Search Scopes, and About tabs
  Onboarding/
    OnboardingView.swift          -- Multi-step onboarding with glass cards and animations
    SplashView.swift              -- Branded launch screen with spring animations
  SnythingApp.swift               -- AppDelegate, menu bar, window lifecycle, dock icon toggle
```

---

## Keyboard Shortcuts Reference

| Shortcut | Context | Action |
|----------|---------|--------|
| `⌘Space` | Anywhere | Toggle search window |
| `↑` | Results list | Select previous |
| `↓` | Results list | Select next |
| `Enter` | Results list | Open selected file |
| `⌘Enter` | Results list | Reveal selected file in Finder |
| `Space` | Results list | Toggle preview panel |
| `Esc` | Anywhere in search | Hide window (or close preview if open) |
| `A-Z, 0-9` | Results list | Type into search bar (auto-focuses) |

---

## Development

```bash
# Debug build
swift build

# Run tests
swift test

# Release build + .app bundle
.github/build_app.sh

# Release build + DMG
.github/build_app.sh && .github/create_dmg.sh
```

The release `.app` will be at `.build/Snything.app` and the DMG at `.build/Snything-Release.dmg`.

---

## Auto-Update

Snything can automatically check for new releases on GitHub and install them for you:

- **Check for Updates**: On launch, if enabled, the app queries the GitHub Releases API for the latest DMG.
- **One-Click Install**: When an update is found, a notification appears. Clicking it downloads the new DMG, mounts it, replaces the app in `/Applications`, and relaunches.
- **Toggle in Settings**: You can enable or disable automatic update checking from **Settings > General** at any time.
- **Onboarding Choice**: During first-launch onboarding, you're asked whether you want automatic updates enabled.

---

## License

Snything is open-source software.
