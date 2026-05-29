import SwiftUI
import AppKit

struct OnboardingContainerView: View {
    @StateObject private var permissions = PermissionsManager()
    @State private var currentStep = 0
    @State private var isComplete = false
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            VisualEffectMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.20),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            if isComplete {
                CompletionStepView(onComplete: onComplete)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.02)),
                        removal: .opacity
                    ))
            } else {
                VStack(spacing: 0) {
                    StepIndicator(current: currentStep, total: 3)
                        .padding(.top, 28)
                        .padding(.bottom, 24)

                    Group {
                        switch currentStep {
                        case 0: WelcomeStepView()
                        case 1: PermissionsStepView(permissions: permissions)
                        case 2: ShortcutStepView(permissions: permissions)
                        default: EmptyView()
                        }
                    }
                    .frame(maxHeight: .infinity)

                    HStack(spacing: 12) {
                        if currentStep > 0 {
                            Button("Back") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    currentStep -= 1
                                }
                            }
                            .buttonStyle(OnboardingButtonStyle(secondary: true))
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        Spacer()

                        Button(nextButtonTitle) {
                            if currentStep == 2 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    isComplete = true
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    currentStep += 1
                                }
                            }
                        }
                        .buttonStyle(OnboardingButtonStyle())
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
            }
        }
        .frame(width: 540, height: 460)
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case 2: "Get Started"
        default: "Continue"
        }
    }
}

struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { idx in
                Capsule()
                    .fill(idx == current ? Color.accentColor : Color.secondary.opacity(0.15))
                    .frame(width: idx == current ? 28 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: current)
            }
        }
    }
}

struct WelcomeStepView: View {
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0
    @State private var glowScale: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [.accentColor.opacity(0.15), .cyan.opacity(0.10), .accentColor.opacity(0.15)]),
                            center: .center
                        )
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(glowScale)

                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .accentColor.opacity(0.25), radius: 12, x: 0, y: 4)
            }
            .scaleEffect(scale)
            .opacity(opacity)

            VStack(spacing: 12) {
                Text("Welcome to Snything")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("A minimalist, blazing-fast search for your Mac.\nLet's set it up in just a few steps.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(opacity)
        }
        .padding(.horizontal, 36)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                glowScale = 1.0
            }
        }
    }
}

struct PermissionsStepView: View {
    @ObservedObject var permissions: PermissionsManager
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 22) {
            Text("Permissions")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Snything needs access to search everywhere\nand listen for global keyboard shortcuts.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            VStack(spacing: 14) {
                PermissionRow(
                    icon: "externaldrive.fill",
                    iconColor: .blue,
                    title: "Full Disk Access",
                    subtitle: "Search inside protected system folders",
                    isGranted: permissions.hasFullDiskAccess
                ) {
                    permissions.openFullDiskAccessSettings()
                }

                PermissionRow(
                    icon: "keyboard.fill",
                    iconColor: .purple,
                    title: "Accessibility",
                    subtitle: "Register global keyboard shortcuts",
                    isGranted: permissions.hasAccessibility
                ) {
                    permissions.requestAccessibility()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        permissions.refresh()
                    }
                }
            }
            .padding(.horizontal, 24)

            Button("Check Again") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    pulse.toggle()
                }
                permissions.refresh()
            }
            .buttonStyle(OnboardingButtonStyle(secondary: true))
            .scaleEffect(pulse ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pulse)
        }
        .onAppear {
            permissions.refresh()
        }
    }
}

struct ShortcutStepView: View {
    @ObservedObject var permissions: PermissionsManager

    var body: some View {
        VStack(spacing: 22) {
            Text("Global Shortcut")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Open Snything from anywhere with a single keystroke.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    OnboardingShortcutBadge(text: "⌘")
                    OnboardingShortcutBadge(text: "Space")
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.accentColor.opacity(0.35),
                                            Color.cyan.opacity(0.15)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )

                VStack(alignment: .leading, spacing: 10) {
                    Label("Press ⌘Space anywhere to open Snything", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.85))

                    Label("Disable Spotlight ⌘Space in System Settings first", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.orange.opacity(0.85))
                }
                .padding(.horizontal, 32)

                Button("Open Keyboard Settings") {
                    permissions.openSpotlightShortcutSettings()
                }
                .buttonStyle(OnboardingButtonStyle(secondary: true))
            }
        }
    }
}

struct CompletionStepView: View {
    let onComplete: () -> Void
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0
    @State private var glowScale: CGFloat = 0.6

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 90, height: 90)
                    .scaleEffect(glowScale)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .scaleEffect(scale)
            .opacity(opacity)

            VStack(spacing: 10) {
                Text("You're all set!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Press ⌘Space to start searching.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.85))
                    .tracking(0.3)
            }
            .opacity(opacity)

            Button("Start Searching") {
                onComplete()
            }
            .buttonStyle(OnboardingButtonStyle())
            .opacity(opacity)
        }
        .padding(.horizontal, 36)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.1)) {
                glowScale = 1.0
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isGranted: Bool
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(iconColor.opacity(0.18), lineWidth: 1)
                        )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(OnboardingButtonStyle(compact: true))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(hover ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(hover ? 0.12 : 0.06), lineWidth: 1)
                )
        )
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) {
                hover = h
            }
        }
    }
}

struct OnboardingShortcutBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.primary.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            )
    }
}

struct OnboardingButtonStyle: ButtonStyle {
    var secondary = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 14, weight: .semibold, design: .rounded))
            .foregroundColor(secondary ? .primary.opacity(0.9) : .white)
            .padding(.horizontal, compact ? 16 : 24)
            .padding(.vertical, compact ? 7 : 11)
            .background(
                secondary
                    ? AnyView(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
                    : AnyView(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.05)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
            )
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
