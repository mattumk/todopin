import SwiftUI

/// Drag-to-reorder de blocs catégorie.
/// Architecture identique à ReorderableTaskList :
/// état ET gesture définis sur la vue parent → closures stables → zéro interruption.
struct DraggableCategoryList: View {
    @ObservedObject var taskManager: TaskManager

    @State private var draggingId:  UUID?   = nil
    @State private var dragY:       CGFloat = 0
    @State private var fromIndex:   Int?    = nil
    @State private var targetIndex: Int?    = nil

    private let spacing:      CGFloat = 8
    private let headerHeight: CGFloat = 38   // hauteur de la zone poignée

    private var categories: [TaskCategory] { taskManager.activeCategories }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { i, cat in
                let isDragging = draggingId == cat.id

                DraggableCategoryBlock(
                    category:       cat,
                    taskManager:    taskManager,
                    neighborOffset: neighborOffset(for: i),
                    dragOffset:     isDragging ? dragY : 0,
                    isDragging:     isDragging
                )
                // Overlay transparent sur l'en-tête uniquement → seul handle de drag
                // Le gesture est défini ICI (sur la vue qui possède l'état) → stable entre renders
                .overlay(alignment: .top) {
                    Color.clear
                        .frame(height: headerHeight)
                        .contentShape(Rectangle())
                        .gesture(blockDrag(for: cat, at: i))
                }
                .animation(
                    isDragging ? nil : .spring(response: 0.28, dampingFraction: 0.78),
                    value: neighborOffset(for: i)
                )
                .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isDragging)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: categories.map(\.id))
        .padding(.horizontal, 20)
    }

    // MARK: - Gesture (défini sur DraggableCategoryList → accède aux @State via self)

    private func blockDrag(for cat: TaskCategory, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if draggingId == nil {
                    draggingId  = cat.id
                    fromIndex   = index
                    targetIndex = index
                }
                guard draggingId == cat.id, let from = fromIndex else { return }
                dragY = value.translation.height
                let step = estimatedHeight(for: cat)
                let raw  = Int((dragY / step).rounded())
                let new  = max(0, min(categories.count - 1, from + raw))
                if new != targetIndex { targetIndex = new }
            }
            .onEnded { _ in
                commitOrder()
                resetDrag()
            }
    }

    // MARK: - Helpers

    private func neighborOffset(for i: Int) -> CGFloat {
        guard let from = fromIndex, let to = targetIndex,
              categories.indices.contains(from) else { return 0 }
        let h = estimatedHeight(for: categories[from])
        if from < to && i > from && i <= to { return -h }
        if from > to && i >= to  && i < from { return  h }
        return 0
    }

    private func estimatedHeight(for cat: TaskCategory) -> CGFloat {
        let n = taskManager.pendingTasks(for: cat).count
        return 46 + CGFloat(n) * 58 + spacing
    }

    private func commitOrder() {
        guard let from = fromIndex, let to = targetIndex, from != to else { return }
        var reordered = categories
        let item = reordered.remove(at: from)
        reordered.insert(item, at: to)
        taskManager.reorderCategories(ids: reordered.map(\.id))
    }

    private func resetDrag() {
        draggingId = nil; dragY = 0; fromIndex = nil; targetIndex = nil
    }
}

// MARK: - Bloc individuel (pur, pas de gesture)

private struct DraggableCategoryBlock: View {
    let category:       TaskCategory
    @ObservedObject var taskManager: TaskManager
    let neighborOffset: CGFloat
    let dragOffset:     CGFloat
    let isDragging:     Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ── En-tête ──────────────────────────────────────────────────
            HStack(spacing: 5) {
                Circle()
                    .fill(category.swiftUIColor)
                    .frame(width: 7, height: 7)
                Text(category.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(category.swiftUIColor)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundColor(category.swiftUIColor.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)

            // ── Tâches ───────────────────────────────────────────────────
            ReorderableTaskList(
                taskManager: taskManager,
                tasks: taskManager.pendingTasks(for: category)
            )
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(category.swiftUIColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(category.swiftUIColor.opacity(0.22), lineWidth: 1)
                )
        )
        .offset(y: neighborOffset + dragOffset)
        .scaleEffect(isDragging ? 1.015 : 1.0, anchor: .center)
        .shadow(
            color:  isDragging ? Color.black.opacity(0.18) : .clear,
            radius: isDragging ? 14 : 0,
            y:      isDragging ? 5  : 0
        )
    }
}
