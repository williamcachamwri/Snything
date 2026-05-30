import SwiftUI
import AppKit

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: Toast? = nil
    @Published var isVisible: Bool = false

    private var queue: [Toast] = []
    private var dismissTask: Task<Void, Never>? = nil
    private var toastPanel: ToastPanel?

    private init() {}

    func show(icon: String, title: String, subtitle: String? = nil, color: Color = .accentColor) {
        let toast = Toast(icon: icon, title: title, subtitle: subtitle, color: color)
        queue.append(toast)
        if currentToast == nil {
            presentNext()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        isVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            self?.currentToast = nil
            self?.presentNext()
        }
    }

    private func presentNext() {
        guard !queue.isEmpty else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
                self?.toastPanel?.orderOut(nil)
            }
            return
        }
        let toast = queue.removeFirst()
        currentToast = toast
        ensurePanel()
        isVisible = true
        toastPanel?.orderFront(nil)

        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func ensurePanel() {
        if toastPanel == nil {
            toastPanel = ToastPanel()
        }
        toastPanel?.positionAtBottomCenter()
    }
}

// MARK: - Toast Panel

final class ToastPanel: NSPanel {
    init() {
        let panelHeight: CGFloat = 84
        let panelWidth: CGFloat = 340
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .stationary]

        // Container view handles shadow + corner radius
        let container = NSView()
        container.wantsLayer = true
        container.layer = CALayer()
        container.layer?.cornerRadius = 14
        container.layer?.masksToBounds = false
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.45
        container.layer?.shadowRadius = 20
        container.layer?.shadowOffset = NSSize(width: 0, height: 8)
        container.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        container.autoresizingMask = [.width, .height]

        // Visual effect view inside container (clipped to corners)
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1
        effectView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.12).cgColor
        effectView.frame = container.bounds
        effectView.autoresizingMask = [.width, .height]
        container.addSubview(effectView)

        // Hosting view for SwiftUI content
        let hosting = NSHostingView(rootView: ToastPanelContent())
        hosting.frame = effectView.bounds
        hosting.autoresizingMask = [.width, .height]
        effectView.addSubview(hosting)

        self.contentView = container
    }

    func positionAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let size = self.frame.size
        let x = screenRect.midX - size.width / 2
        let y = screenRect.minY + 48
        self.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

// MARK: - Toast Content

struct ToastPanelContent: View {
    @StateObject private var manager = ToastManager.shared

    var body: some View {
        ZStack(alignment: .center) {
            if manager.isVisible, let toast = manager.currentToast {
                toastCard(toast)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.92)),
                        removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.92))
                    ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: manager.isVisible)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: manager.currentToast?.id)
    }

    private func toastCard(_ toast: Toast) -> some View {
        HStack(spacing: 12) {
            Image(systemName: toast.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(toast.color)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(toast.color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                if let subtitle = toast.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
