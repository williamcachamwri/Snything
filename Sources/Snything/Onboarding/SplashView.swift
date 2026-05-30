import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var lineWidth: CGFloat = 0
    @State private var hasTriggered = false

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Subtle radial glow
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(0.05),
                    Color.clear
                ]),
                center: .center,
                startRadius: 60,
                endRadius: 250
            )

            // Frosted glass panel
            VisualEffectMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            VStack(spacing: 32) {
                ZStack {
                    // Soft single orb behind
                    Circle()
                        .fill(Color.accentColor.opacity(0.10))
                        .frame(width: 120, height: 120)
                        .blur(radius: 24)

                    // Logo
                    if let icon = Bundle.main.image(forResource: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.20), radius: 12, x: 0, y: 4)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accentColor, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .accentColor.opacity(0.30), radius: 12, x: 0, y: 4)
                    }
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                VStack(spacing: 8) {
                    Text("Snything")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(0.4)

                    Text("Search everything, instantly")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.75))
                        .tracking(0.5)

                    // Minimal line indicator
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: lineWidth, height: 3)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 0)
                        .padding(.top, 8)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .frame(width: 380, height: 280)
        .onAppear {
            guard !hasTriggered else { return }
            hasTriggered = true

            // Icon bounces in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }

            // Text fades up
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                textOpacity = 1.0
                textOffset = 0
            }

            // Line grows
            withAnimation(.easeOut(duration: 0.6).delay(0.45)) {
                lineWidth = 40
            }

            // Settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    iconOpacity = 0
                    textOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onComplete()
                }
            }
        }
    }
}
