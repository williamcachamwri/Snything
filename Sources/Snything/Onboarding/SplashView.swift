import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.2
    @State private var iconOpacity: Double = 0
    @State private var iconRotation: Double = -15

    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 40

    @State private var orb1Scale: CGFloat = 0.4
    @State private var orb1Opacity: Double = 0
    @State private var orb2Scale: CGFloat = 0.3
    @State private var orb2Opacity: Double = 0
    @State private var orb3Scale: CGFloat = 0.2
    @State private var orb3Opacity: Double = 0

    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var ringRotation: Double = 0

    @State private var progress: CGFloat = 0
    @State private var progressOpacity: Double = 0

    @State private var shimmerOffset: CGFloat = -200
    @State private var hasTriggered = false

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Deep radial gradient background
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(0.08),
                    Color.black.opacity(0.02)
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()

            // Enhanced floating particles
            EnhancedParticlesView()

            // Outer glass border
            VisualEffectMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05),
                                    Color.accentColor.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )

            VStack(spacing: 42) {
                ZStack {
                    // Layer 3: outer cyan orb
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.cyan.opacity(0.12),
                                    Color.cyan.opacity(0.02)
                                ]),
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 220, height: 220)
                        .scaleEffect(orb3Scale)
                        .opacity(orb3Opacity)
                        .blur(radius: 35)

                    // Layer 2: mid pink orb
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.pink.opacity(0.14),
                                    Color.pink.opacity(0.03)
                                ]),
                                center: .center,
                                startRadius: 20,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(orb2Scale)
                        .opacity(orb2Opacity)
                        .blur(radius: 28)

                    // Layer 1: inner accent orb
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor.opacity(0.20),
                                    Color.cyan.opacity(0.12),
                                    Color.pink.opacity(0.10),
                                    Color.accentColor.opacity(0.20)
                                ]),
                                center: .center
                            )
                        )
                        .frame(width: 150, height: 150)
                        .scaleEffect(orb1Scale)
                        .opacity(orb1Opacity)
                        .blur(radius: 22)

                    // Animated ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor.opacity(0.6),
                                    Color.cyan.opacity(0.4),
                                    Color.accentColor.opacity(0.1),
                                    Color.accentColor.opacity(0.6)
                                ]),
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                        .rotationEffect(.degrees(ringRotation))

                    // Secondary dashed ring
                    Circle()
                        .stroke(
                            Color.white.opacity(0.15),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 8])
                        )
                        .frame(width: 108, height: 108)
                        .scaleEffect(ringScale * 0.95)
                        .opacity(ringOpacity * 0.7)
                        .rotationEffect(.degrees(-ringRotation * 0.5))

                    // App Icon Logo
                    if let icon = Bundle.main.image(forResource: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 88, height: 88)
                            .compositingGroup()
                            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                            .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 5)
                            .shadow(color: Color.accentColor.opacity(0.25), radius: 20, x: 0, y: 0)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accentColor, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .accentColor.opacity(0.35), radius: 14, x: 0, y: 5)
                    }
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .rotation3DEffect(.degrees(iconRotation), axis: (x: 0, y: 1, z: 0))

                VStack(spacing: 14) {
                    ZStack {
                        Text("Snything")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .tracking(0.5)

                        // Shimmer overlay
                        Text("Snything")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.0),
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .tracking(0.5)
                            .mask(
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.clear, .white, .clear]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 80)
                                        .offset(x: shimmerOffset)
                                }
                            )
                    }

                    Text("Search everything, instantly")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.85))
                        .tracking(0.6)

                    // Progress bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                            .frame(width: 140, height: 5)

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.cyan.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 140 * progress, height: 5)
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 0)
                    }
                    .opacity(progressOpacity)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .frame(width: 420, height: 340)
        .onAppear {
            guard !hasTriggered else { return }
            hasTriggered = true

            // Outer orbs cascade in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.55).delay(0.05)) {
                orb3Scale = 1.0
                orb3Opacity = 1.0
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.12)) {
                orb2Scale = 1.0
                orb2Opacity = 1.0
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.2)) {
                orb1Scale = 1.0
                orb1Opacity = 1.0
            }

            // Ring burst
            withAnimation(.spring(response: 0.65, dampingFraction: 0.5).delay(0.25)) {
                ringScale = 1.0
                ringOpacity = 1.0
            }

            // Icon bounces in with 3D tilt
            withAnimation(.spring(response: 0.65, dampingFraction: 0.55).delay(0.35)) {
                iconScale = 1.0
                iconOpacity = 1.0
                iconRotation = 0
            }

            // Text slides up
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                textOpacity = 1.0
                textOffset = 0
                progressOpacity = 1.0
            }

            // Progress fills
            withAnimation(.easeInOut(duration: 1.6).delay(0.8)) {
                progress = 1.0
            }

            // Shimmer sweeps across
            withAnimation(.easeInOut(duration: 1.2).delay(1.0)) {
                shimmerOffset = 200
            }

            // Ring continuous rotation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false).delay(0.5)) {
                ringRotation = 360
            }

            // Complete after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    iconOpacity = 0
                    textOpacity = 0
                    orb1Opacity = 0
                    orb2Opacity = 0
                    orb3Opacity = 0
                    ringOpacity = 0
                    progressOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Enhanced Particles
struct EnhancedParticlesView: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30, paused: false)) { _ in
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let count = 30
                for i in 0..<count {
                    let t = phase * 0.15 + Double(i) * 1.7
                    let x = sin(t * 0.4 + Double(i) * 1.3) * w * 0.42 + w * 0.5
                    let y = cos(t * 0.3 + Double(i) * 0.9) * h * 0.38 + h * 0.5
                    let r = (1.0 + sin(t + Double(i) * 0.5)) * 1.2
                    let opacity = 0.06 + sin(phase * 0.3 + Double(i) * 0.7) * 0.04
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.white.opacity(opacity))
                    )
                }
                // Draw a few larger accent particles
                for i in 0..<6 {
                    let t = phase * 0.1 + Double(i) * 3.0
                    let x = sin(t * 0.5 + Double(i) * 2.1) * w * 0.35 + w * 0.5
                    let y = cos(t * 0.4 + Double(i) * 1.5) * h * 0.30 + h * 0.5
                    let r = 2.5 + sin(t + Double(i)) * 1.0
                    let opacity = 0.10 + sin(phase * 0.2 + Double(i) * 1.2) * 0.05
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.accentColor.opacity(opacity))
                    )
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                    phase = 1000
                }
            }
        }
    }
}
