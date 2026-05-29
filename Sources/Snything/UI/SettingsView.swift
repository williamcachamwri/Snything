import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedTab = 0
    @State private var isAnimated = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VisualEffectMaterialView()
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "gear")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text("Settings")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                HStack(spacing: 0) {
                    ForEach(0..<3) { idx in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                selectedTab = idx
                            }
                        } label: {
                            Text(["General", "Search", "About"][idx])
                                .font(.system(size: 12, weight: selectedTab == idx ? .semibold : .medium, design: .rounded))
                                .foregroundColor(selectedTab == idx ? .accentColor : .secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case 0: GeneralSettingsView()
                        case 1: SearchSettingsView()
                        case 2: AboutSettingsView()
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(width: 440, height: 400)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05)) {
                isAnimated = true
            }
        }
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            ToggleRow(
                icon: "eye.fill",
                title: "Show Hidden Files",
                subtitle: "Include dot-prefixed files in search",
                isOn: $settings.showHiddenFiles
            )

            ToggleRow(
                icon: "rectangle.split.2x1.fill",
                title: "Auto Preview",
                subtitle: "Show preview panel on selection",
                isOn: $settings.showPreviewOnSelect
            )

            ToggleRow(
                icon: "power",
                title: "Launch at Login",
                subtitle: "Start automatically when logging in",
                isOn: $settings.launchAtLogin
            )

            ToggleRow(
                icon: "arrow.down.circle.fill",
                title: "Auto Check for Updates",
                subtitle: "Notify when a new release is available",
                isOn: $settings.autoCheckUpdates
            )

            SliderRow(
                icon: "timer",
                title: "Search Delay",
                value: $settings.searchDelay,
                range: 0...300,
                step: 10,
                format: { "\(Int($0))ms" }
            )

            SliderRow(
                icon: "list.number",
                title: "Max Results",
                value: $settings.maxResults,
                range: 50...500,
                step: 50,
                format: { "\(Int($0))" }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Search Scopes")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(settings.searchScopes.count) selected")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 4)

            VStack(spacing: 1) {
                ForEach(availableScopes, id: \.path) { scope in
                    let isSelected = settings.searchScopes.contains(scope.path)
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            var scopes = settings.searchScopes
                            if isSelected {
                                scopes.removeAll { $0 == scope.path }
                            } else {
                                scopes.append(scope.path)
                            }
                            settings.searchScopes = scopes
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "checkmark" : "")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.accentColor)
                                .frame(width: 14)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(scope.name)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                Text(scope.path)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.06) : Color.clear
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - About Settings
struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            AppLogoImage(size: 48)

            VStack(spacing: 2) {
                Text("Snything")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Version \(appVersion)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Text("A minimalist, blazing-fast search for your Mac.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                LinkButton(title: "GitHub", url: "https://github.com/williamcachamwri/Snything")
                LinkButton(title: "Support", url: "https://github.com/williamcachamwri/Snything/issues")
                LinkButton(title: "Report", url: "https://github.com/williamcachamwri/Snything/issues/new")
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Row Components

struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.7))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
    }
}

struct SliderRow: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Text(format(value))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(minWidth: 40, alignment: .trailing)
            }

            Slider(value: $value, in: range, step: step)
                .tint(.accentColor)
                .padding(.leading, 32)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
    }
}

struct LinkButton: View {
    let title: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}
