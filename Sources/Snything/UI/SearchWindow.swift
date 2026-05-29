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
        panel.isMovableByWindowBackground = true
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

    override func showWindow(_ sender: Any?) {
        guard let window = window else { return }
        window.center()
        NSApp.activate(ignoringOtherApps: true)

        let contentLayer = window.contentView?.layer
        contentLayer?.setValue(0.82, forKeyPath: "transform.scale.x")
        contentLayer?.setValue(0.82, forKeyPath: "transform.scale.y")
        contentLayer?.setValue(0.0, forKeyPath: "opacity")
        window.makeKeyAndOrderFront(sender)

        let spring = CASpringAnimation(keyPath: "transform.scale.x")
        spring.mass = 0.8
        spring.stiffness = 200
        spring.damping = 22
        spring.initialVelocity = 6
        spring.fromValue = 0.82
        spring.toValue = 1.0
        spring.duration = spring.settlingDuration

        let springY = CASpringAnimation(keyPath: "transform.scale.y")
        springY.mass = 0.8
        springY.stiffness = 200
        springY.damping = 22
        springY.initialVelocity = 6
        springY.fromValue = 0.82
        springY.toValue = 1.0
        springY.duration = springY.settlingDuration

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.0
        fade.toValue = 1.0
        fade.duration = 0.18
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)

        contentLayer?.add(spring, forKey: "scaleX")
        contentLayer?.add(springY, forKey: "scaleY")
        contentLayer?.add(fade, forKey: "fade")

        contentLayer?.setValue(1.0, forKeyPath: "transform.scale.x")
        contentLayer?.setValue(1.0, forKeyPath: "transform.scale.y")
        contentLayer?.setValue(1.0, forKeyPath: "opacity")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.forceFocusSearchField()
        }
    }

    func hideWindow() {
        guard let window = window, let contentLayer = window.contentView?.layer else { return }

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        fade.duration = 0.10
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1.0
        shrink.toValue = 0.96
        shrink.duration = 0.10
        shrink.timingFunction = CAMediaTimingFunction(name: .easeIn)

        contentLayer.add(fade, forKey: "fadeOut")
        contentLayer.add(shrink, forKey: "shrink")
        contentLayer.setValue(0.0, forKeyPath: "opacity")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            window.orderOut(nil)
            contentLayer.setValue(1.0, forKeyPath: "opacity")
            contentLayer.setValue(1.0, forKeyPath: "transform.scale")
        }
    }

    func toggleVisibility() {
        guard let window = window else { return }
        if window.isVisible {
            hideWindow()
        } else {
            showWindow(nil)
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
