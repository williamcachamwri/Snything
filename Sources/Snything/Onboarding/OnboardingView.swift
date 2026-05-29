import SwiftUI
import AppKit

// MARK: - Floating Particle Background
struct FloatingParticlesView: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30, paused: false)) { _ in
            Canvas { context, size in
                let w = size.width
                let h = size.height
                for i in 0..<18 {
                    let x = sin(phase * 0.3 + Double(i) * 1.3) * w * 0.4 + w * 0.5
                    let y = cos(phase * 0.2 + Double(i) * 0.9) * h * 0.4 + h * 0.5
                    let r = 1.5 + sin(phase + Double(i)) * 0.8
                    let opacity = 0.08 + sin(phase * 0.5 + Double(i) * 0.7) * 0.04
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.white.opacity(opacity))
                    )
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    phase = 1000
                }
            }
        }
    }
}

// MARK: - Gradient Orb
struct GradientOrbView: View {
    @State private var rotation: Double = 0
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor.opacity(0.18),
                            Color.pink.opacity(0.10),
                            Color.cyan.opacity(0.12),
                            Color.accentColor.opacity(0.18)
                        ]),
                        center: .center,
                        angle: .degrees(rotation)
                    )
                )
                .frame(width: 140, height: 140)
                .scaleEffect(pulse)
                .blur(radius: 20)
                .opacity(0.8)
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulse = 1.15
            }
        }
    }
}

// MARK: - Onboarding Container
struct OnboardingContainerView: View {
    @StateObject private var permissions = PermissionsManager()
    @State private var currentStep = 0
    @State private var isComplete = false
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            VisualEffectMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            FloatingParticlesView()

            if isComplete {
                CompletionStepView(onComplete: onComplete)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.02)),
                        removal: .opacity
                    ))
            } else {
                VStack(spacing: 0) {
                    StepIndicator(current: currentStep, total: 3)
                        .padding(.top, 32)
                        .padding(.bottom, 20)

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
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    currentStep -= 1
                                }
                            }
                            .buttonStyle(OnboardingButtonStyle(secondary: true))
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        Spacer()

                        Button(nextButtonTitle) {
                            if currentStep == 2 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                    isComplete = true
                                }
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
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

// MARK: - Step Indicator
struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { idx in
                Capsule()
                    .fill(idx == current ? Color.accentColor : Color.secondary.opacity(0.12))
                    .frame(width: idx == current ? 32 : 8, height: 8)
                    .shadow(
                        color: idx == current ? Color.accentColor.opacity(0.3) : Color.clear,
                        radius: idx == current ? 6 : 0
                    )
                    .animation(.spring(response: 0.45, dampingFraction: 0.7), value: current)
            }
        }
    }
}

// MARK: - Welcome Step
struct WelcomeStepView: View {
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0
    @State private var glowOpacity: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                GradientOrbView()

                AppLogoImage(size: 80)
                    .shadow(color: .accentColor.opacity(0.25), radius: 16, x: 0, y: 6)
            }
            .scaleEffect(scale)
            .opacity(opacity)

            VStack(spacing: 14) {
                Text("Welcome to Snything")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("A minimalist, blazing-fast search for your Mac.\nLet's set it up in just a few steps.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .tracking(0.2)
            }
            .opacity(opacity)
        }
        .padding(.horizontal, 36)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.68).delay(0.05)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                glowOpacity = 1.0
            }
        }
    }
}

// MARK: - Permissions Step
struct PermissionsStepView: View {
    @ObservedObject var permissions: PermissionsManager
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Permissions")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .tracking(0.3)

            Text("Snything needs access to search everywhere\nand listen for global keyboard shortcuts.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            VStack(spacing: 12) {
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

// MARK: - Shortcut Step
struct ShortcutStepView: View {
    @ObservedObject var permissions: PermissionsManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Global Shortcut")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .tracking(0.3)

            Text("Open Snything from anywhere with a single keystroke.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    OnboardingShortcutBadge(text: "⌘")
                    OnboardingShortcutBadge(text: "Space")
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 44)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.secondary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.accentColor.opacity(0.40),
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

// MARK: - Completion Step
struct CompletionStepView: View {
    let onComplete: () -> Void
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0
    @State private var glowScale: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                GradientOrbView()

                AppLogoImage(size: 80)
                    .shadow(color: .accentColor.opacity(0.30), radius: 16, x: 0, y: 6)
                    .scaleEffect(glowScale)
            }
            .scaleEffect(scale)
            .opacity(opacity)

            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(0.3)

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
            .scaleEffect(scale)
        }
        .padding(.horizontal, 36)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.68)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                glowScale = 1.0
            }
        }
    }
}

// MARK: - Permission Row
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
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(iconColor.opacity(0.22), lineWidth: 1)
                        )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.75))
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
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
                        .stroke(Color.white.opacity(hover ? 0.14 : 0.06), lineWidth: 1)
                )
        )
        .scaleEffect(hover ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.12), value: hover)
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
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - App Logo Image (from bundle resources)
struct AppLogoImage: View {
    let size: CGFloat

    var body: some View {
        if let icon = Bundle.module.image(forResource: "AppIcon") {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .compositingGroup()
                .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: size * 0.15, x: 0, y: size * 0.06)
        } else {
            Image(systemName: "magnifyingglass")
                .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}
