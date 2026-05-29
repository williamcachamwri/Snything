import SwiftUI
import AppKit

@main
struct SnythingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    private var searchWindowController: SearchWindowController?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideSearch),
            name: .snythingHideWindow,
            object: nil
        )

        let hasCompleted = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        if hasCompleted {
            showSplashThenMain()
        } else {
            showOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            searchWindowController?.showWindow(nil)
        }
        return true
    }

    @objc private func handleHideSearch() {
        searchWindowController?.hideWindow()
    }

    @objc private func showSearch() {
        searchWindowController?.toggleVisibility()
    }

    @objc private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: hasCompletedOnboardingKey)
        searchWindowController?.hideWindow()
        searchWindowController = nil
        GlobalHotkeyManager.shared.unregister()
        showOnboarding()
    }

    @objc private func showSettings() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = createHostingWindow(
            rootView: SettingsView(),
            size: NSSize(width: 480, height: 420)
        )
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

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

        let resetItem = NSMenuItem(title: "Reset Onboarding", action: #selector(resetOnboarding), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func showSplashThenMain() {
        let splashWindow = createHostingWindow(
            rootView: SplashView {
                self.closeOnboardingWindow()
                self.setupSearchWindow()
            },
            size: NSSize(width: 420, height: 320)
        )
        self.onboardingWindow = splashWindow
        splashWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOnboarding() {
        let window = createHostingWindow(
            rootView: OnboardingContainerView {
                UserDefaults.standard.set(true, forKey: self.hasCompletedOnboardingKey)
                self.closeOnboardingWindow()
                self.showSplashThenMain()
            },
            size: NSSize(width: 520, height: 440)
        )
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupSearchWindow() {
        searchWindowController = SearchWindowController()
        searchWindowController?.showWindow(nil)

        GlobalHotkeyManager.shared.registerDefaultShortcut { [weak self] in
            self?.searchWindowController?.toggleVisibility()
        }
    }

    private func closeOnboardingWindow() {
        onboardingWindow?.orderOut(nil)
        onboardingWindow = nil
    }

    private func createHostingWindow<Content: View>(
        rootView: Content,
        size: NSSize
    ) -> NSWindow {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.center()
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = false

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hostingView

        return panel
    }
}

extension Notification.Name {
    static let snythingHideWindow = Notification.Name("snythingHideWindow")
}
