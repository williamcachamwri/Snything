import SwiftUI

struct UpdateAlertView: View {
    @StateObject private var updateManager = UpdateManager.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    updateManager.skipUpdate()
                }

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 70, height: 70)

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("Update Available")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Snything v\(updateManager.alertVersion) has been released.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                HStack(spacing: 10) {
                    Button {
                        updateManager.skipUpdate()
                    } label: {
                        Text("Later")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.secondary.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        updateManager.installUpdate()
                    } label: {
                        Text("Install Update")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(
                ZStack {
                    VisualEffectMaterialView()
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(width: 340)
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }
}
