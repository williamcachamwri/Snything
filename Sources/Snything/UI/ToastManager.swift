import SwiftUI
import Combine

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
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.currentToast = nil
            self?.presentNext()
        }
    }

    private func presentNext() {
        guard !queue.isEmpty else { return }
        let toast = queue.removeFirst()
        currentToast = toast
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isVisible = true
        }
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }
}

struct ToastView: View {
    @StateObject private var manager = ToastManager.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if manager.isVisible, let toast = manager.currentToast {
                    toastCard(toast)
                        .position(x: geo.size.width / 2, y: geo.size.height - 60)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                            removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9))
                        ))
                }
            }
        }
        .allowsHitTesting(false)
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
        .padding(.horizontal, 20)
    }
}
