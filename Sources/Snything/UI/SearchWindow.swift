import SwiftUI
import AppKit
import QuartzCore

final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var hidesOnDeactivate: Bool {
        get { false }
        set { }
    }
}

final class SearchWindowController: NSWindowController {
    init() {
        let panel = SearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.center()
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true
        panel.isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: SearchContainerView())
        hosting.frame = NSRect(x: 0, y: 0, width: 780, height: 560)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 20
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting

        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Show

    override func showWindow(_ sender: Any?) {
        guard let window = window else { return }
        window.center()
        NSApp.activate(ignoringOtherApps: true)

        let layer = window.contentView?.layer

        // Initial state: invisible, smaller, and slightly shifted down
        layer?.setValue(0.88, forKeyPath: "transform.scale.x")
        layer?.setValue(0.88, forKeyPath: "transform.scale.y")
        layer?.setValue(24.0, forKeyPath: "transform.translation.y")
        layer?.setValue(0.0, forKeyPath: "opacity")
        layer?.setValue(0.0, forKeyPath: "shadowOpacity")

        window.makeKeyAndOrderFront(sender)

        // --- Scale X: snappy spring ---
        let springX = CASpringAnimation(keyPath: "transform.scale.x")
        springX.mass = 0.55
        springX.stiffness = 320
        springX.damping = 20
        springX.initialVelocity = 10
        springX.fromValue = 0.88
        springX.toValue = 1.0
        springX.duration = springX.settlingDuration
        springX.fillMode = .forwards

        // --- Scale Y: slightly different mass for organic feel ---
        let springY = CASpringAnimation(keyPath: "transform.scale.y")
        springY.mass = 0.6
        springY.stiffness = 300
        springY.damping = 20
        springY.initialVelocity = 10
        springY.fromValue = 0.88
        springY.toValue = 1.0
        springY.duration = springY.settlingDuration
        springY.fillMode = .forwards

        // --- Translate Y: slide up from below ---
        let slide = CASpringAnimation(keyPath: "transform.translation.y")
        slide.mass = 0.6
        slide.stiffness = 280
        slide.damping = 22
        slide.initialVelocity = 8
        slide.fromValue = 24.0
        slide.toValue = 0.0
        slide.duration = slide.settlingDuration
        slide.fillMode = .forwards

        // --- Opacity: smooth fade in ---
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.0
        fade.toValue = 1.0
        fade.duration = 0.22
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fade.fillMode = .forwards

        // --- Shadow opacity: shadow builds up with the scale ---
        let shadowFade = CABasicAnimation(keyPath: "shadowOpacity")
        shadowFade.fromValue = 0.0
        shadowFade.toValue = 0.35
        shadowFade.duration = 0.28
        shadowFade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        shadowFade.fillMode = .forwards

        layer?.add(springX, forKey: "scaleX")
        layer?.add(springY, forKey: "scaleY")
        layer?.add(slide, forKey: "slideY")
        layer?.add(fade, forKey: "fade")
        layer?.add(shadowFade, forKey: "shadowFade")

        // Lock final values so they stick
        layer?.setValue(1.0, forKeyPath: "transform.scale.x")
        layer?.setValue(1.0, forKeyPath: "transform.scale.y")
        layer?.setValue(0.0, forKeyPath: "transform.translation.y")
        layer?.setValue(1.0, forKeyPath: "opacity")
        layer?.setValue(0.35, forKeyPath: "shadowOpacity")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            self.forceFocusSearchField()
        }
    }

    // MARK: - Hide

    func hideWindow() {
        guard let window = window, let layer = window.contentView?.layer else { return }

        // --- Opacity: fast fade out ---
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        fade.duration = 0.12
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        fade.fillMode = .forwards

        // --- Scale: shrink slightly with more punch ---
        let shrinkX = CABasicAnimation(keyPath: "transform.scale.x")
        shrinkX.fromValue = 1.0
        shrinkX.toValue = 0.94
        shrinkX.duration = 0.12
        shrinkX.timingFunction = CAMediaTimingFunction(name: .easeIn)
        shrinkX.fillMode = .forwards

        let shrinkY = CABasicAnimation(keyPath: "transform.scale.y")
        shrinkY.fromValue = 1.0
        shrinkY.toValue = 0.94
        shrinkY.duration = 0.12
        shrinkY.timingFunction = CAMediaTimingFunction(name: .easeIn)
        shrinkY.fillMode = .forwards

        // --- Slide down slightly as it disappears ---
        let slideDown = CABasicAnimation(keyPath: "transform.translation.y")
        slideDown.fromValue = 0.0
        slideDown.toValue = 12.0
        slideDown.duration = 0.12
        slideDown.timingFunction = CAMediaTimingFunction(name: .easeIn)
        slideDown.fillMode = .forwards

        // --- Shadow fades with the window ---
        let shadowOut = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOut.fromValue = 0.35
        shadowOut.toValue = 0.0
        shadowOut.duration = 0.10
        shadowOut.timingFunction = CAMediaTimingFunction(name: .easeIn)
        shadowOut.fillMode = .forwards

        layer.add(fade, forKey: "fadeOut")
        layer.add(shrinkX, forKey: "shrinkX")
        layer.add(shrinkY, forKey: "shrinkY")
        layer.add(slideDown, forKey: "slideDown")
        layer.add(shadowOut, forKey: "shadowOut")

        layer.setValue(0.0, forKeyPath: "opacity")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            window.orderOut(nil)
            // Reset for next show
            layer.setValue(1.0, forKeyPath: "transform.scale.x")
            layer.setValue(1.0, forKeyPath: "transform.scale.y")
            layer.setValue(0.0, forKeyPath: "transform.translation.y")
            layer.setValue(1.0, forKeyPath: "opacity")
            layer.setValue(0.0, forKeyPath: "shadowOpacity")
        }
    }

    func toggleVisibility() {
        guard let window = window else { return }
        if window.isVisible {
            hideWindow()
        } else {
            showWindow(nil)
            NotificationCenter.default.post(name: .snythingResetToFiles, object: nil)
        }
    }

    private func forceFocusSearchField() {
        guard let window = window else { return }
        func findTextField(_ view: NSView) -> NSView? {
            for subview in view.subviews {
                if let tf = subview as? NSTextField { return tf }
                if let found = findTextField(subview) { return found }
            }
            return nil
        }
        if let textField = findTextField(window.contentView!) {
            window.makeFirstResponder(textField)
        }
    }
}

struct VisualEffectMaterialView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 20
        view.layer?.masksToBounds = true
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { }
}

struct SearchContainerView: View {
    var body: some View {
        ZStack {
            VisualEffectMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.06)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            SearchView()
        }
    }
}
