import SwiftUI

struct SettingsView: View {
    @State private var searchDelay: Double = 60
    @State private var maxResults: Double = 200
    @State private var showHiddenFiles: Bool = false
    @State private var showPreviewOnSelect: Bool = false
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
                        case 0: GeneralSettingsView(
                            searchDelay: $searchDelay,
                            maxResults: $maxResults,
                            showHiddenFiles: $showHiddenFiles,
                            showPreviewOnSelect: $showPreviewOnSelect
                        )
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

struct GeneralSettingsView: View {
    @Binding var searchDelay: Double
    @Binding var maxResults: Double
    @Binding var showHiddenFiles: Bool
    @Binding var showPreviewOnSelect: Bool

    var body: some View {
        VStack(spacing: 16) {
            SettingsToggleRow(
                icon: "eye.fill",
                iconColor: .blue,
                title: "Show Hidden Files",
                subtitle: "Include dot-prefixed files in search",
                isOn: $showHiddenFiles
            )

            SettingsToggleRow(
                icon: "rectangle.split.2x1.fill",
                iconColor: .purple,
                title: "Auto Preview",
                subtitle: "Show preview panel on selection",
                isOn: $showPreviewOnSelect
            )

            SettingsSliderRow(
                icon: "timer",
                iconColor: .orange,
                title: "Search Delay",
                subtitle: "\(Int(searchDelay))ms",
                value: $searchDelay,
                range: 0...200
            )

            SettingsSliderRow(
                icon: "list.number",
                iconColor: .green,
                title: "Max Results",
                subtitle: "\(Int(maxResults)) items",
                value: $maxResults,
                range: 50...500
            )
        }
    }
}

struct SearchSettingsView: View {
    @State private var selectedScopes: Set<String> = [
        NSHomeDirectory(),
        "/Applications",
        "/Users"
    ]
    let availableScopes = [
        (path: NSHomeDirectory(), name: "Home Directory"),
        (path: "/Applications", name: "Applications"),
        (path: "/Users", name: "All Users"),
        (path: "/opt", name: "Opt"),
        (path: "/usr/local", name: "Local"),
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("Search Scopes")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ForEach(availableScopes, id: \.path) { scope in
                    let isSelected = selectedScopes.contains(scope.path)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isSelected {
                                selectedScopes.remove(scope.path)
                            } else {
                                selectedScopes.insert(scope.path)
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scope.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text(scope.path)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
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

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 70, height: 70)
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

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

            HStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com")!) {
                    Label("GitHub", systemImage: "globe")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(SettingsLinkStyle())

                Link(destination: URL(string: "https://windsurf.com/support")!) {
                    Label("Support", systemImage: "questionmark.circle")
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
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer()
            }

            Slider(value: $value, in: range, step: 10)
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
