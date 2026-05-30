import SwiftUI

struct ClipboardPreviewView: View {
    let item: ClipboardItem
    var onClearAll: () -> Void

    @State private var sourceAppIcon: NSImage? = nil
    @State private var imageContent: NSImage? = nil
    @State private var isHoveringClear = false
    @State private var isPressingClear = false
    @State private var isClearing = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var flashOpacity: Double = 0
    @State private var showFormattedJSON = true

    var body: some View {
        ZStack {
            previewBody
                .opacity(isClearing ? 0 : 1)
                .scaleEffect(isClearing ? 0.88 : 1)
                .blur(radius: isClearing ? 6 : 0)

            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.18), value: isClearing)
        .animation(.easeOut(duration: 0.12), value: flashOpacity)
        .onAppear {
            loadSourceAppIcon()
            loadImageIfNeeded()
        }
    }

    @ViewBuilder
    private var previewBody: some View {
        VStack(spacing: 0) {
            contentAreaWithBadge
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !item.sourceBundleID.isEmpty {
                bottomBar
            }
        }
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var contentAreaWithBadge: some View {
        ZStack(alignment: .bottomTrailing) {
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 8)

            if let sourceAppIcon {
                appIconBadge(icon: sourceAppIcon)
            }
        }
        .overlay(alignment: .topTrailing) {
            clearButtonArea
                .padding(.top, 12)
                .padding(.trailing, 12)
        }
    }

    private func appIconBadge(icon: NSImage) -> some View {
        HStack(spacing: 6) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Text(item.sourceAppName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
        .padding(.trailing, 12)
        .padding(.bottom, 12)
    }

    private var clearButtonArea: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.25))
                .frame(width: 80, height: 80)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)

            Button {
                performClear()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isPressingClear ? -15 : 0))
                        .offset(y: isPressingClear ? 2 : 0)

                    Text("Clear")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundColor(
                    isPressingClear ? .white :
                    (isHoveringClear ? .red.opacity(0.95) : .secondary.opacity(0.7))
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            isPressingClear ? Color.red :
                            (isHoveringClear ? Color.red.opacity(0.14) : Color.secondary.opacity(0.08))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isPressingClear ? Color.red.opacity(0.6) :
                            (isHoveringClear ? Color.red.opacity(0.35) : Color.white.opacity(0.06)),
                            lineWidth: isHoveringClear ? 1.2 : 0.5
                        )
                )
                .shadow(
                    color: isHoveringClear ? Color.red.opacity(0.35) : Color.clear,
                    radius: isHoveringClear ? 10 : 0,
                    x: 0,
                    y: isHoveringClear ? 3 : 0
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressingClear ? 0.88 : (isHoveringClear ? 1.06 : 1.0))
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    isHoveringClear = hovering
                }
            }
            .pressEvents {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) {
                    isPressingClear = true
                }
            } onRelease: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressingClear = false
                }
            }
        }
    }

    private func performClear() {
        withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) {
            isPressingClear = true
        }
        rippleScale = 0.3
        rippleOpacity = 1.0
        withAnimation(.easeOut(duration: 0.35)) {
            rippleScale = 1.8
            rippleOpacity = 0.0
        }
        withAnimation(.easeIn(duration: 0.06)) {
            flashOpacity = 0.45
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeOut(duration: 0.25)) {
                flashOpacity = 0.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isClearing = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onClearAll()
            withAnimation(.none) {
                isClearing = false
                isPressingClear = false
            }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        switch item.type {
        case .image:
            imagePreview
        case .text, .rtf:
            smartTextPreview
        case .url:
            urlPreview
        case .file:
            filePreview
        }
    }

    @ViewBuilder
    private var smartTextPreview: some View {
        switch item.smartType {
        case .hexColor, .rgbColor:
            colorPreview
        case .json:
            jsonPreview
        case .code:
            codePreview
        case .number:
            numberPreview
        case .email:
            emailPreview
        case .phone:
            phonePreview
        case .command:
            commandPreview
        case .url:
            urlPreview
        default:
            plainTextPreview
        }
    }

    private var colorPreview: some View {
        guard let rgb = item.smartInfo?.rgbValues else { return AnyView(plainTextPreview) }
        let color = Color(red: Double(rgb.r)/255.0, green: Double(rgb.g)/255.0, blue: Double(rgb.b)/255.0)
        return AnyView(
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 80, height: 80)
                        .shadow(color: color.opacity(0.4), radius: 16, x: 0, y: 4)
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 80, height: 80)
                }

                VStack(spacing: 4) {
                    Text(item.content)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)

                    Text("RGB(\(rgb.r), \(rgb.g), \(rgb.b))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    if let swiftUI = item.smartInfo?.swiftUIColor {
                        copyButton(label: "SwiftUI", value: swiftUI)
                    }
                    if let css = item.smartInfo?.cssColor {
                        copyButton(label: "CSS", value: css)
                    }
                    copyButton(label: "Hex", value: item.content)
                }
                .padding(.top, 4)

                Spacer()
            }
            .padding(.top, 40)
        )
    }

    private var jsonPreview: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                    Text("JSON")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                )

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showFormattedJSON.toggle()
                    }
                } label: {
                    Text(showFormattedJSON ? "Minify" : "Format")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.accentColor.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView(.vertical, showsIndicators: true) {
                Text(showFormattedJSON ? (item.smartInfo?.formattedJSON ?? item.content) : (item.smartInfo?.minifiedJSON ?? item.content))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.9))
                    .lineSpacing(2)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.15))
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    private var codePreview: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.purple)
                    Text(item.smartInfo?.detectedLanguage?.uppercased() ?? "CODE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.purple.opacity(0.12))
                )

                Spacer()

                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(item.content, forType: .string)
                    ToastManager.shared.show(icon: "doc.on.doc", title: "Copied code", color: .purple)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Copy")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.purple.opacity(0.10))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView(.vertical, showsIndicators: true) {
                Text(item.content)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.9))
                    .lineSpacing(3)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.15))
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    private var numberPreview: some View {
        VStack(spacing: 20) {
            if let result = item.smartInfo?.expressionResult {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.12))
                        .frame(width: 80, height: 80)
                    VStack(spacing: 0) {
                        Text(String(format: "%g", result))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.teal)
                    }
                }

                Text(item.content)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Text(item.content)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.teal)
                }
            }

            HStack(spacing: 8) {
                copyButton(label: "Copy", value: item.content)
            }

            Spacer()
        }
        .padding(.top, 40)
    }

    private var emailPreview: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "envelope.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.cyan)
            }

            VStack(spacing: 4) {
                Text(item.content)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                Button {
                    if let url = URL(string: "mailto:\(item.content)") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Compose", systemImage: "envelope")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.cyan)
                        )
                }
                .buttonStyle(.plain)

                copyButton(label: "Copy", value: item.content)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 40)
    }

    private var phonePreview: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "phone.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            }

            Text(item.content)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Button {
                    if let url = URL(string: "tel:\(item.content.filter { $0.isNumber })") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Call", systemImage: "phone")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.green)
                        )
                }
                .buttonStyle(.plain)

                copyButton(label: "Copy", value: item.content)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 40)
    }

    private var commandPreview: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    Text("SHELL COMMAND")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.gray.opacity(0.12))
                )

                Spacer()

                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(item.content, forType: .string)
                    ToastManager.shared.show(icon: "doc.on.doc", title: "Copied command", color: .gray)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Copy")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.gray.opacity(0.10))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView(.vertical, showsIndicators: true) {
                Text(item.content)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.9))
                    .lineSpacing(3)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.15))
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    private var plainTextPreview: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(item.content)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
                .lineSpacing(4)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var imagePreview: some View {
        Group {
            if let imageContent {
                Image(nsImage: imageContent)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
            } else if item.content != "Image",
                      FileManager.default.fileExists(atPath: item.content),
                      let nsImage = NSImage(contentsOfFile: item.content) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
            } else {
                placeholderView(icon: "photo", text: "Image Preview")
            }
        }
    }

    private var urlPreview: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 6) {
                Text("URL")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(item.content)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 8) {
                Button {
                    if let url = URL(string: item.content) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Open", systemImage: "safari")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.blue)
                        )
                }
                .buttonStyle(.plain)

                copyButton(label: "Copy", value: item.content)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 40)
    }

    private var filePreview: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "doc.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }

            VStack(spacing: 6) {
                Text(URL(fileURLWithPath: item.content).lastPathComponent)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(item.content)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.selectFile(item.content, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Reveal", systemImage: "folder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: item.content))
                } label: {
                    Label("Open", systemImage: "arrow.up.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 40)
    }

    private func copyButton(label: String, value: String) -> some View {
        Button {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(value, forType: .string)
            ToastManager.shared.show(icon: "doc.on.doc", title: "Copied \(label)", color: .accentColor)
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func placeholderView(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomBar: some View {
        HStack {
            Spacer()

            Text(item.displaySubtitle)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.05))
                )
                .padding(.trailing, 12)
                .padding(.bottom, 8)
        }
    }

    private func loadSourceAppIcon() {
        guard !item.sourceBundleID.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.sourceBundleID) else { return }
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            let resized = icon.resized(to: NSSize(width: 40, height: 40))
            DispatchQueue.main.async {
                self.sourceAppIcon = resized
            }
        }
    }

    private func loadImageIfNeeded() {
        guard item.type == .image else { return }
        let path = item.content
        guard path != "Image", FileManager.default.fileExists(atPath: path) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOfFile: path) {
                DispatchQueue.main.async {
                    self.imageContent = image
                }
            }
        }
    }
}

// MARK: - Press Event Modifier (macOS compatible)

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}
