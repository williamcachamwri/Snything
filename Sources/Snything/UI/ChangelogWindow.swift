import SwiftUI
import AppKit
import QuartzCore

final class ChangelogPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

final class ChangelogWindowController: NSWindowController {
    static let shared = ChangelogWindowController()

    private init() {
        let panel = ChangelogPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .modalPanel
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.center()
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: ChangelogContainerView())
        hosting.frame = NSRect(x: 0, y: 0, width: 460, height: 540)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 16
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting

        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAnimated() {
        guard let window = window else { return }
        window.center()
        NSApp.activate(ignoringOtherApps: true)

        let layer = window.contentView?.layer
        layer?.setValue(0.88, forKeyPath: "transform.scale.x")
        layer?.setValue(0.88, forKeyPath: "transform.scale.y")
        layer?.setValue(20.0, forKeyPath: "transform.translation.y")
        layer?.setValue(0.0, forKeyPath: "opacity")
        layer?.setValue(0.0, forKeyPath: "shadowOpacity")

        window.makeKeyAndOrderFront(nil)

        let springX = CASpringAnimation(keyPath: "transform.scale.x")
        springX.mass = 0.5
        springX.stiffness = 350
        springX.damping = 20
        springX.initialVelocity = 12
        springX.fromValue = 0.88
        springX.toValue = 1.0
        springX.duration = springX.settlingDuration
        springX.fillMode = .forwards

        let springY = CASpringAnimation(keyPath: "transform.scale.y")
        springY.mass = 0.55
        springY.stiffness = 330
        springY.damping = 20
        springY.initialVelocity = 12
        springY.fromValue = 0.88
        springY.toValue = 1.0
        springY.duration = springY.settlingDuration
        springY.fillMode = .forwards

        let slide = CASpringAnimation(keyPath: "transform.translation.y")
        slide.mass = 0.5
        slide.stiffness = 300
        slide.damping = 22
        slide.initialVelocity = 10
        slide.fromValue = 20.0
        slide.toValue = 0.0
        slide.duration = slide.settlingDuration
        slide.fillMode = .forwards

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.0
        fade.toValue = 1.0
        fade.duration = 0.25
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fade.fillMode = .forwards

        let shadowFade = CABasicAnimation(keyPath: "shadowOpacity")
        shadowFade.fromValue = 0.0
        shadowFade.toValue = 0.4
        shadowFade.duration = 0.32
        shadowFade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        shadowFade.fillMode = .forwards

        layer?.add(springX, forKey: "scaleX")
        layer?.add(springY, forKey: "scaleY")
        layer?.add(slide, forKey: "slideY")
        layer?.add(fade, forKey: "fade")
        layer?.add(shadowFade, forKey: "shadowFade")

        layer?.setValue(1.0, forKeyPath: "transform.scale.x")
        layer?.setValue(1.0, forKeyPath: "transform.scale.y")
        layer?.setValue(0.0, forKeyPath: "transform.translation.y")
        layer?.setValue(1.0, forKeyPath: "opacity")
        layer?.setValue(0.4, forKeyPath: "shadowOpacity")
    }

    func dismissAnimated() {
        guard let window = window, let layer = window.contentView?.layer else { return }

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        fade.duration = 0.15
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        fade.fillMode = .forwards

        let shrinkX = CABasicAnimation(keyPath: "transform.scale.x")
        shrinkX.fromValue = 1.0
        shrinkX.toValue = 0.95
        shrinkX.duration = 0.15
        shrinkX.timingFunction = CAMediaTimingFunction(name: .easeIn)
        shrinkX.fillMode = .forwards

        let shrinkY = CABasicAnimation(keyPath: "transform.scale.y")
        shrinkY.fromValue = 1.0
        shrinkY.toValue = 0.95
        shrinkY.duration = 0.15
        shrinkY.timingFunction = CAMediaTimingFunction(name: .easeIn)
        shrinkY.fillMode = .forwards

        let slideDown = CABasicAnimation(keyPath: "transform.translation.y")
        slideDown.fromValue = 0.0
        slideDown.toValue = 16.0
        slideDown.duration = 0.15
        slideDown.timingFunction = CAMediaTimingFunction(name: .easeIn)
        slideDown.fillMode = .forwards

        layer.add(fade, forKey: "fadeOut")
        layer.add(shrinkX, forKey: "shrinkX")
        layer.add(shrinkY, forKey: "shrinkY")
        layer.add(slideDown, forKey: "slideDown")
        layer.setValue(0.0, forKeyPath: "opacity")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) { [weak self] in
            window.orderOut(nil)
            layer.setValue(1.0, forKeyPath: "transform.scale.x")
            layer.setValue(1.0, forKeyPath: "transform.scale.y")
            layer.setValue(0.0, forKeyPath: "transform.translation.y")
            layer.setValue(1.0, forKeyPath: "opacity")
            layer.setValue(0.0, forKeyPath: "shadowOpacity")
            self?.updateManager.showAlert = false
        }
    }

    private var updateManager: UpdateManager { UpdateManager.shared }
}

struct ChangelogContainerView: View {
    var body: some View {
        ZStack {
            VisualEffectMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            ChangelogView()
        }
    }
}
