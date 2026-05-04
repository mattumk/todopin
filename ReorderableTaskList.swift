import SwiftUI

/// Drag-to-reorder fluide : le tableau ne change PAS d'ordre pendant le drag.
/// On déplace seulement les voisins par offset. L'ordre est commité au relâché.
struct ReorderableTaskList: View {
    @ObservedObject var taskManager: TaskManager
    let tasks: [Task]

    // ── État drag ──────────────────────────────────────────────────────
    @State private var draggingId:  UUID?   = nil
    @State private var dragY:       CGFloat = 0    // translation brute
    @State private var fromIndex:   Int?    = nil  // index de départ
    @State private var targetIndex: Int?    = nil  // index cible courant

    private let rowH:    CGFloat = 52
    private let spacing: CGFloat = 6
    private var step: CGFloat { rowH + spacing }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { i, task in
                let isDragging = draggingId == task.id

                TaskRowView(task: task, taskManager: taskManager)
                    .offset(y: isDragging ? dragY : neighborOffset(for: i))
                    .scaleEffect(isDragging ? 1.03 : 1.0, anchor: .center)
                    .shadow(
                        color: isDragging ? Color.black.opacity(0.22) : Color.clear,
                        radius: isDragging ? 16 : 0,
                        y:      isDragging ? 5  : 0
                    )
                    .zIndex(isDragging ? 100 : 0)
                    // Les voisins s'animent quand targetIndex change
                    .animation(
                        .spring(response: 0.28, dampingFraction: 0.78),
                        value: targetIndex
                    )
                    // Pickup / drop (scale + ombre)
                    .animation(
                        .spring(response: 0.22, dampingFraction: 0.75),
                        value: isDragging
                    )
                    // Transition d'apparition / disparition
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 0.88))
                    ))
                    .gesture(drag(for: task, at: i))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: tasks.map(\.id))
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    // MARK: - Offset des voisins

    private func neighborOffset(for i: Int) -> CGFloat {
        guard let from = fromIndex, let to = targetIndex else { return 0 }
        if from < to {
            // glisse vers le bas → les items entre from+1 et to remontent
            if i > from && i <= to { return -step }
        } else if from > to {
            // glisse vers le haut → les items entre to et from-1 descendent
            if i >= to && i < from { return step }
        }
        return 0
    }

    // MARK: - Geste

    private func drag(for task: Task, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                if draggingId == nil {
                    draggingId  = task.id
                    fromIndex   = index
                    targetIndex = index
                }
                guard draggingId == task.id, let from = fromIndex else { return }

                dragY = value.translation.height
                // Calcul de l'index cible : swap à mi-chemin
                let raw = Int((dragY / step).rounded())
                targetIndex = max(0, min(tasks.count - 1, from + raw))
            }
            .onEnded { _ in
                guard let from = fromIndex, let to = targetIndex else {
                    resetDrag(); return
                }
                // Commit de l'ordre
                if from != to {
                    var reordered = tasks
                    let item = reordered.remove(at: from)
                    reordered.insert(item, at: to)
                    taskManager.reorderPendingTasks(ids: reordered.map(\.id))
                }
                // Reset instantané — les positions visuelles correspondent déjà
                // au nouvel ordre, donc pas de saut visible
                resetDrag()
            }
    }

    private func resetDrag() {
        draggingId  = nil
        dragY       = 0
        fromIndex   = nil
        targetIndex = nil
    }
}
