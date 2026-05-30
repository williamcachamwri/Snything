import SwiftUI
import AppKit
import ServiceManagement

@main
struct SnythingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var onboardingWindow: NSWindow?
    private var onboardingBackdrop: NSWindow?
    private var searchWindowController: SearchWindowController?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var outsideClickMonitor: Any?
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private let hasShownSplashKey = "hasShownSplash"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start hidden until onboarding decides
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        FileSystemMonitor.shared.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideSearch),
            name: .snythingHideWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReRegisterHotkey),
            name: .snythingReRegisterHotkey,
            object: nil
        )

        let hasCompleted = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        let hasShownSplash = UserDefaults.standard.bool(forKey: hasShownSplashKey)
        if hasCompleted {
            hideDockIcon()
            if hasShownSplash {
                setupSearchWindow()
                checkForUpdatesIfEnabled()
            } else {
                showSplashThenMain()
            }
        } else {
            showDockIcon()
            showOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        FileSystemMonitor.shared.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            searchWindowController?.showWindow(nil)
        }
        return true
    }

    func applicationDidResignActive(_ notification: Notification) {
        // Clicking outside the app (desktop, other app) during onboarding dismisses it
        if onboardingWindow != nil {
            dismissOnboardingProceedToSplash()
        }
    }

    // MARK: - Dock Icon

    private func showDockIcon() {
        NSApp.setActivationPolicy(.regular)
    }

    private func hideDockIcon() {
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Search Window

    @objc private func handleHideSearch() {
        searchWindowController?.hideWindow()
    }

    @objc private func showSearch() {
        searchWindowController?.toggleVisibility()
    }

    @objc private func handleReRegisterHotkey() {
        GlobalHotkeyManager.shared.unregister()
        GlobalHotkeyManager.shared.registerDefaultShortcut { [weak self] in
            guard let self = self else { return }
            self.searchWindowController?.toggleVisibility()
        }
    }

    // MARK: - Onboarding

    @objc private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: hasCompletedOnboardingKey)
        searchWindowController?.hideWindow()
        searchWindowController = nil
        GlobalHotkeyManager.shared.unregister()
        showDockIcon()
        showOnboarding()
    }

    private func showOnboarding() {
        let window = createHostingWindow(
            rootView: OnboardingContainerView {
                self.dismissOnboardingProceedToSplash()
            },
            size: NSSize(width: 520, height: 440)
        )
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Click outside dismisses onboarding
        startOutsideClickMonitor()
    }

    private func dismissOnboardingProceedToSplash() {
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
        closeOnboardingWindow()
        hideDockIcon()
        showSplashThenMain()
    }

    private func closeOnboardingWindow() {
        stopOutsideClickMonitor()
        onboardingBackdrop?.orderOut(nil)
        onboardingBackdrop = nil
        onboardingWindow?.orderOut(nil)
        onboardingWindow = nil
    }

    // MARK: - Click Outside Monitor

    private func startOutsideClickMonitor() {
        // Monitor clicks within our app that land outside the onboarding window
        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, let window = self.onboardingWindow else { return event }
            if event.window !== window {
                self.dismissOnboardingProceedToSplash()
            }
            return event
        }
    }

    private func stopOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    // MARK: - Splash

    private func showSplashThenMain() {
        let splashWindow = createHostingWindow(
            rootView: SplashView {
                UserDefaults.standard.set(true, forKey: self.hasShownSplashKey)
                self.closeOnboardingWindow()
                self.setupSearchWindow()
                self.checkForUpdatesIfEnabled()
            },
            size: NSSize(width: 420, height: 320)
        )
        self.onboardingWindow = splashWindow
        splashWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func checkForUpdatesIfEnabled() {
        if SettingsManager.shared.autoCheckUpdates {
            UpdateManager.shared.startAutomaticChecks()
        }
    }

    // MARK: - Settings

    @objc private func showSettings() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // Hide search and unregister hotkey to avoid capture conflicts
        searchWindowController?.hideWindow()
        GlobalHotkeyManager.shared.unregister()

        let window = createHostingWindow(
            rootView: SettingsView(),
            size: NSSize(width: 480, height: 420),
            level: .modalPanel
        )
        window.delegate = self
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdates() {
        UpdateManager.shared.checkForUpdates(showAnyway: true)
    }

    // MARK: - NSWindowDelegate (Settings)

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == settingsWindow else { return }
        settingsWindow = nil
        // Re-register global hotkey after settings closes
        GlobalHotkeyManager.shared.registerDefaultShortcut { [weak self] in
            self?.searchWindowController?.toggleVisibility()
        }
    }

    @objc private func grantFolderAccess() {
        Task { @MainActor in
            let granted = await BookmarkManager.shared.requestAccess()
            if granted {
                BookmarkManager.shared.restoreAccess()
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: "Snything"
        )
        statusItem?.button?.imagePosition = .imageLeading

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Search", action: #selector(showSearch), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let accessItem = NSMenuItem(title: "Grant Folder Access...", action: #selector(grantFolderAccess), keyEquivalent: "")
        accessItem.target = self
        menu.addItem(accessItem)

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        let resetItem = NSMenuItem(title: "Reset Onboarding", action: #selector(resetOnboarding), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Search Window

    private func setupSearchWindow() {
        guard searchWindowController == nil else {
            searchWindowController?.showWindow(nil)
            return
        }

        // Restore persisted folder access bookmarks
        BookmarkManager.shared.restoreAccess()

        // If we have neither bookmarks nor Full Disk Access, prompt the user once
        if !BookmarkManager.shared.hasBookmark {
            let hasFDA = PermissionsManager().checkFullDiskAccess()
            if !hasFDA {
                Task { @MainActor in
                    let granted = await BookmarkManager.shared.requestAccess()
                    if !granted {
                        print("[Snything] User declined folder access; TCC popups may appear.")
                    }
                }
            }
        }

        searchWindowController = SearchWindowController()
        searchWindowController?.showWindow(nil)

        // Start background OCR indexing on app launch
        OCRIndexManager.shared.startBackgroundIndex(for: SettingsManager.shared.ocrSearchScopes)

        GlobalHotkeyManager.shared.registerDefaultShortcut { [weak self] in
            self?.searchWindowController?.toggleVisibility()
        }
    }

    // MARK: - Window Factory

    private func createHostingWindow<Content: View>(
        rootView: Content,
        size: NSSize,
        level: NSWindow.Level = .floating
    ) -> NSWindow {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = level
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.center()
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = false

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hostingView

        return panel
    }

}

// MARK: - Launch at Login Manager

final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published var isEnabled: Bool {
        didSet {
            if isEnabled {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    private init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

extension Notification.Name {
    static let snythingHideWindow = Notification.Name("snythingHideWindow")
    static let snythingReRegisterHotkey = Notification.Name("snythingReRegisterHotkey")
    static let snythingResetToFiles = Notification.Name("snythingResetToFiles")
}
