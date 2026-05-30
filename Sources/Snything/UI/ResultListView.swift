import SwiftUI
import AppKit

struct ResultListView: View {
    @ObservedObject var coordinator: SearchCoordinator
    var namespace: Namespace.ID

    private var searchTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .offset(y: 8)),
            removal: .opacity.combined(with: .scale(scale: 0.96))
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(coordinator.results.enumerated()), id: \.element.id) { index, result in
                            ResultRowView(
                                result: result,
                                isSelected: index == coordinator.selectedIndex,
                                isMultiSelected: coordinator.selectedIndices.contains(index) && index != coordinator.selectedIndex,
                                namespace: namespace,
                                isDeleting: coordinator.deletingResultID?.contains(result.id) ?? false,
                                selectionCount: coordinator.selectedIndices.count
                            )
                            .id(result.id)
                            .contentShape(Rectangle())
                            .transition(searchTransition)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    coordinator.selectIndex(index)
                                }
                                coordinator.openSelected()
                            }
                            .simultaneousGesture(
                                TapGesture(count: 1)
                                    .modifiers(.command)
                                    .onEnded { _ in
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                            coordinator.toggleSelection(at: index)
                                        }
                                    }
                            )
                            .onHover { hover in
                                guard hover else { return }
                                let shift = NSEvent.modifierFlags.contains(.shift)
                                if shift {
                                    guard index != coordinator.selectedIndex else { return }
                                    if coordinator.lastAnchorIndex == nil {
                                        coordinator.lastAnchorIndex = coordinator.selectedIndex
                                    }
                                    coordinator.selectIndex(index, shiftHeld: true)
                                } else if coordinator.selectedIndices.isEmpty {
                                    coordinator.selectIndex(index)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(Color.clear)
                .onChange(of: coordinator.keyboardFocusedIndex) { _, newValue in
                    guard coordinator.isKeyboardNavigating else { return }
                    if coordinator.results.indices.contains(newValue) {
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(coordinator.results[newValue].id, anchor: .center)
                        }
                    }
                }
            }

            // Selection count pill
            if coordinator.selectedIndices.count > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(coordinator.selectedIndices.count) selected")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.92))
                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 2)
                )
                .padding(.trailing, 12)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxHeight: .infinity)
    }
}
