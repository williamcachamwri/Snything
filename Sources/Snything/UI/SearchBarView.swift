import SwiftUI

struct SearchBarView: View {
    @Binding var query: String
    var isSearching: Bool
    var onQueryChange: (String) -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)

            TextField("Search files, apps, folders...", text: $query)
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .textFieldStyle(.plain)
                .foregroundColor(.primary)
                .onChange(of: query) { _, newValue in
                    onQueryChange(newValue)
                }

            if !query.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.2)) {
                        query = ""
                        onQueryChange("")
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            if isSearching {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                    .scaleEffect(0.7)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(isHovered ? 0.22 : 0.10),
                                Color.white.opacity(0.04)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hover
            }
        }
    }
}
