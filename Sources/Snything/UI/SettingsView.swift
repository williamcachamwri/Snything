import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedTab = 0
    @State private var isAnimated = false

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

            VStack(spacing: 0) {
                settingsHeader
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                settingsTabs
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case 0: GeneralSettingsView()
                        case 1: SearchSettingsView()
                        case 2: AboutSettingsView()
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(width: 480, height: 420)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05)) {
                isAnimated = true
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "gear")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Settings")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 28)
        .opacity(isAnimated ? 1 : 0)
        .offset(y: isAnimated ? 0 : 10)
    }

    private var settingsTabs: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { idx in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedTab = idx
                    }
                } label: {
                    Text(tabTitle(for: idx))
                        .font(.system(size: 13, weight: selectedTab == idx ? .semibold : .medium, design: .rounded))
                        .foregroundColor(selectedTab == idx ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedTab == idx ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func tabTitle(for idx: Int) -> String {
        ["General", "Search", "About"][idx]
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 14) {
            SettingsToggleRow(
                icon: "eye.fill",
                iconColor: .blue,
                title: "Show Hidden Files",
                subtitle: "Include dot-prefixed files in search",
                isOn: Binding(
                    get: { settings.showHiddenFiles },
                    set: { settings.showHiddenFiles = $0 }
                )
            )

            SettingsToggleRow(
                icon: "rectangle.split.2x1.fill",
                iconColor: .purple,
                title: "Auto Preview",
                subtitle: "Show preview panel on selection",
                isOn: Binding(
                    get: { settings.showPreviewOnSelect },
                    set: { settings.showPreviewOnSelect = $0 }
                )
            )

            SettingsToggleRow(
                icon: "power",
                iconColor: .green,
                title: "Launch at Login",
                subtitle: "Start Snything automatically when logging in",
                isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                )
            )

            SettingsSliderRow(
                icon: "timer",
                iconColor: .orange,
                title: "Search Delay",
                subtitle: "\(Int(settings.searchDelay))ms",
                value: Binding(
                    get: { settings.searchDelay },
                    set: { settings.searchDelay = $0 }
                ),
                range: 0...300,
                recommended: 60,
                unit: "ms"
            )

            SettingsSliderRow(
                icon: "list.number",
                iconColor: .green,
                title: "Max Results",
                subtitle: "\(Int(settings.maxResults)) items",
                value: Binding(
                    get: { settings.maxResults },
                    set: { settings.maxResults = $0 }
                ),
                range: 50...500,
                recommended: 200,
                unit: ""
            )
        }
    }
}

// MARK: - Search Settings
struct SearchSettingsView: View {
    @StateObject private var settings = SettingsManager.shared

    private var availableScopes: [(path: String, name: String)] {
        [
            (path: NSHomeDirectory(), name: "Home Directory"),
            (path: "/Applications", name: "Applications"),
            (path: "/System/Applications", name: "System Applications"),
            (path: "/Users", name: "All Users"),
            (path: "/Library", name: "System Library"),
            (path: "/opt", name: "Opt"),
            (path: "/usr/local", name: "Local"),
        ]
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Search Scopes")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(settings.searchScopes.count) selected")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            VStack(spacing: 6) {
                ForEach(availableScopes, id: \.path) { scope in
                    let isSelected = settings.searchScopes.contains(scope.path)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            var scopes = settings.searchScopes
                            if isSelected {
                                scopes.removeAll { $0 == scope.path }
                            } else {
                                scopes.append(scope.path)
                            }
                            settings.searchScopes = scopes
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scope.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text(scope.path)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(isSelected ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - About Settings
struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            AppLogoImage(size: 56)
                .shadow(color: .black.opacity(0.20), radius: 10, x: 0, y: 4)

            VStack(spacing: 6) {
                Text("Snything")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Version 1.0.0")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Text("A minimalist, blazing-fast search for your Mac.\nBuilt with SwiftUI and native macOS frameworks.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            HStack(spacing: 10) {
                Link(destination: URL(string: "https://github.com/williamcachamwri/Snything")!) {
                    Label("GitHub", systemImage: "globe")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(SettingsLinkStyle())

                Link(destination: URL(string: "https://github.com/williamcachamwri/Snything/issues")!) {
                    Label("Support", systemImage: "questionmark.circle")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(SettingsLinkStyle())

                Link(destination: URL(string: "https://github.com/williamcachamwri/Snything/issues/new")!) {
                    Label("Report Issue", systemImage: "exclamationmark.bubble")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(SettingsLinkStyle())
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - Settings Row Components

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct SettingsSliderRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let recommended: Double
    let unit: String

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(iconColor.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)

                        if value == recommended {
                            Text("Recommended")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.green.opacity(0.12))
                                )
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer()
            }

            Slider(value: $value, in: range, step: unit == "ms" ? 10 : 50)
                .tint(.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct SettingsLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.primary.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}
