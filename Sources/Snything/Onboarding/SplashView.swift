import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var ringTrim: CGFloat = 0
    @State private var ringRotation: Double = -90
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 28
    @State private var orbScale: CGFloat = 0.6
    @State private var orbOpacity: Double = 0
    @State private var particlePhase: Double = 0

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

            VStack(spacing: 36) {
                ZStack {
                    // Animated orb glow
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor.opacity(0.20),
                                    Color.pink.opacity(0.12),
                                    Color.cyan.opacity(0.14),
                                    Color.accentColor.opacity(0.20)
                                ]),
                                center: .center
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(orbScale)
                        .opacity(orbOpacity)
                        .blur(radius: 18)

                    // Rotating ring
                    Circle()
                        .trim(from: 0, to: ringTrim)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    .accentColor,
                                    .pink,
                                    .cyan,
                                    .accentColor
                                ]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(ringRotation))

                    // Icon
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .accentColor.opacity(0.35), radius: 14, x: 0, y: 5)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                VStack(spacing: 10) {
                    Text("Snything")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(0.5)

                    Text("Search everything, instantly")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.85))
                        .tracking(0.6)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .frame(width: 420, height: 320)
        .onAppear {
            // Orb fades in and pulses
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                orbScale = 1.0
                orbOpacity = 1.0
            }

            // Icon bounces in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.08)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }

            // Ring spins and completes
            withAnimation(.easeOut(duration: 0.7).delay(0.2)) {
                ringTrim = 1.0
                ringRotation = 270
            }

            // Text slides up
            withAnimation(.easeOut(duration: 0.55).delay(0.4)) {
                textOpacity = 1.0
                textOffset = 0
            }

            // Complete after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    iconOpacity = 0
                    textOpacity = 0
                    orbOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}
