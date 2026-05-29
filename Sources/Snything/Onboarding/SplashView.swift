import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: Double = 0
    @State private var ringTrim: CGFloat = 0
    @State private var ringRotation: Double = -90
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 24
    @State private var glowOpacity: Double = 0

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

            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.08))
                        .frame(width: 100, height: 100)
                        .scaleEffect(iconScale * 1.2)
                        .opacity(glowOpacity)

                    Circle()
                        .stroke(Color.secondary.opacity(0.10), lineWidth: 3)
                        .frame(width: 88, height: 88)

                    Circle()
                        .trim(from: 0, to: ringTrim)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.accentColor, .cyan, .accentColor]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(ringRotation))

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                VStack(spacing: 10) {
                    Text("Snything")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Search everything, instantly")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.85))
                        .tracking(0.5)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .frame(width: 420, height: 320)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                glowOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
                textOpacity = 1.0
                textOffset = 0
            }
            withAnimation(.linear(duration: 1.0).delay(0.25)) {
                ringTrim = 1.0
                ringRotation = 270
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    iconOpacity = 0
                    textOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    onComplete()
                }
            }
        }
    }
}
