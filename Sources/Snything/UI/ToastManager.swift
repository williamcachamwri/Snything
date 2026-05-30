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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.currentToast = nil
            self?.presentNext()
        }
    }

    private func presentNext() {
        guard !queue.isEmpty else {
            // Hide panel when queue is empty
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.toastPanel?.orderOut(nil)
            }
            return
        }
        let toast = queue.removeFirst()
        currentToast = toast
        ensurePanel()
        isVisible = true
        toastPanel?.makeKeyAndOrderFront(nil)

        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func ensurePanel() {
        if toastPanel == nil {
            toastPanel = ToastPanel(manager: self)
        }
        toastPanel?.positionAtBottomCenter()
    }
}

final class ToastPanel: NSPanel {
    private weak var manager: ToastManager?

    init(manager: ToastManager) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.manager = manager
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]

        let hosting = NSHostingView(rootView: ToastPanelContent())
        hosting.frame = NSRect(x: 0, y: 0, width: 340, height: 64)
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting
    }

    func positionAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 64
        let x = screenRect.midX - panelWidth / 2
        let y = screenRect.minY + 40 // 40pt from bottom
        self.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}

struct ToastPanelContent: View {
    @StateObject private var manager = ToastManager.shared

    var body: some View {
        ZStack {
            if manager.isVisible, let toast = manager.currentToast {
                toastCard(toast)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                        removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9))
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: manager.isVisible)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: manager.currentToast?.id)
    }

    private func toastCard(_ toast: Toast) -> some View {
        HStack(spacing: 12) {
            Image(systemName: toast.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(toast.color)
                .frame(width: 32, height: 32)
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
        .padding(.vertical, 10)
        .background(
            VisualEffectMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 8)
        .frame(minWidth: 200, maxWidth: 320)
        .padding(.horizontal, 10)
    }
}
