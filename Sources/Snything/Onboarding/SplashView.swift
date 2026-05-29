import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 28
    @State private var orbScale: CGFloat = 0.6
    @State private var orbOpacity: Double = 0

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
                    // Soft orb glow behind logo
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor.opacity(0.18),
                                    Color.cyan.opacity(0.10),
                                    Color.pink.opacity(0.08),
                                    Color.accentColor.opacity(0.18)
                                ]),
                                center: .center
                            )
                        )
                        .frame(width: 150, height: 150)
                        .scaleEffect(orbScale)
                        .opacity(orbOpacity)
                        .blur(radius: 28)

                    // Custom App Icon Logo
                    if let icon = Bundle.module.image(forResource: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 88, height: 88)
                            .compositingGroup()
                            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                            .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 5)
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

            // Text slides up
            withAnimation(.easeOut(duration: 0.55).delay(0.3)) {
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
