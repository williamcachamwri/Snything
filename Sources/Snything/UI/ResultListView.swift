import SwiftUI

struct ResultListView: View {
    @ObservedObject var coordinator: SearchCoordinator
    var namespace: Namespace.ID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(Array(coordinator.results.enumerated()), id: \.element.id) { index, result in
                        ResultRowView(
                            result: result,
                            isSelected: index == coordinator.selectedIndex,
                            namespace: namespace
                        )
                        .id(result.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                coordinator.selectedIndex = index
                            }
                            coordinator.openSelected()
                        }
                        .onHover { hover in
                            if hover {
                                withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                                    coordinator.selectedIndex = index
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .background(Color.clear)
            .onChange(of: coordinator.selectedIndex) { oldValue, newValue in
                if coordinator.results.indices.contains(newValue) {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(coordinator.results[newValue].id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}
