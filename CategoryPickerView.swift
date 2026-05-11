import SwiftUI

/// Sélecteur de catégorie compact.
/// allowCreation: false → masque le bouton "+" (utilisé dans l'édition de tâche)
struct CategoryPickerView: View {
    @ObservedObject var taskManager: TaskManager
    @Binding var selectedCategoryId: UUID?
    var allowCreation: Bool = true

    @State private var showNewForm      = false
    @State private var showAll          = false
    @State private var newName          = ""
    @State private var newColor         = TaskCategory.palette[0]
    @FocusState private var nameFocused: Bool

    // Renommage
    @State private var editingCategory: TaskCategory? = nil
    @State private var editName         = ""
    @State private var editColor        = TaskCategory.palette[0]

    private let maxVisible = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ── Ligne des pills ─────────────────────────────────────────
            HStack(spacing: 6) {
                let visible = showAll
                    ? taskManager.categories
                    : Array(taskManager.categories.prefix(maxVisible))

                ForEach(visible) { cat in
                    CategoryPill(
                        category: cat,
                        isSelected: selectedCategoryId == cat.id
                    ) {
                        selectedCategoryId = selectedCategoryId == cat.id ? nil : cat.id
                    }
                    .contextMenu {
                        Button("Renommer…") {
                            editingCategory = cat
                            editName        = cat.name
                            editColor       = cat.color
                            showNewForm     = false
                        }
                        Divider()
                        Button("Supprimer", role: .destructive) {
                            if selectedCategoryId == cat.id { selectedCategoryId = nil }
                            taskManager.deleteCategory(cat)
                        }
                    }
                }

                if !showAll && taskManager.categories.count > maxVisible {
                    Text("Autres")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(
                            Capsule().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.spring(response: 0.25)) { showAll = true } }
                }

                if allowCreation {
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            editingCategory = nil
                            showNewForm.toggle()
                            if showNewForm {
                                newName  = ""
                                newColor = TaskCategory.randomColor(
                                    excluding: taskManager.categories.map { $0.color }
                                )
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    nameFocused = true
                                }
                            }
                        }
                    } label: {
                        Image(systemName: showNewForm ? "xmark" : "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.secondary.opacity(0.10)))
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()
            }

            // ── Formulaire de création ──────────────────────────────────
            if showNewForm && editingCategory == nil {
                categoryForm(
                    name:    $newName,
                    color:   $newColor,
                    focused: $nameFocused,
                    title:   "Nom de la catégorie",
                    confirmLabel: "Créer",
                    onConfirm: createCategory,
                    onCancel: { withAnimation(.spring(response: 0.25)) { showNewForm = false } }
                )
            }

            // ── Formulaire de renommage ─────────────────────────────────
            if let cat = editingCategory {
                categoryForm(
                    name:    $editName,
                    color:   $editColor,
                    focused: $nameFocused,
                    title:   "Renommer « \(cat.name) »",
                    confirmLabel: "Enregistrer",
                    onConfirm: saveRename,
                    onCancel: { withAnimation(.spring(response: 0.25)) { editingCategory = nil } }
                )
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { nameFocused = true }
                }
            }
        }
    }

    // MARK: - Formulaire réutilisable (création + renommage)

    private func categoryForm(
        name: Binding<String>,
        color: Binding<String>,
        focused: FocusState<Bool>.Binding,
        title: String,
        confirmLabel: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(title, text: name)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .focused(focused)
                .onSubmit { onConfirm() }

            HStack(spacing: 6) {
                ForEach(TaskCategory.palette, id: \.self) { hex in
                    let c = Color(hex: hex) ?? .gray
                    Circle()
                        .fill(c)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().strokeBorder(
                                color.wrappedValue == hex ? Color.primary.opacity(0.6) : Color.clear,
                                lineWidth: 2
                            )
                        )
                        .contentShape(Circle())
                        .onTapGesture { color.wrappedValue = hex }
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Text("Annuler")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.10)))
                    .contentShape(Rectangle())
                    .onTapGesture { onCancel() }

                Text(confirmLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(name.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
                                  ? Color.secondary.opacity(0.3)
                                  : UmakeTheme.navy)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onConfirm() }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(UmakeTheme.navy.opacity(0.10), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Actions

    private func createCategory() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let cat = taskManager.addCategory(name: name, color: newColor)
        selectedCategoryId = cat.id
        withAnimation(.spring(response: 0.25)) { showNewForm = false }
    }

    private func saveRename() {
        let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let cat = editingCategory else { return }
        taskManager.renameCategory(cat.id, name: name, color: editColor)
        withAnimation(.spring(response: 0.25)) { editingCategory = nil }
    }
}

// MARK: - Pill

struct CategoryPill: View {
    let category:   TaskCategory
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(category.swiftUIColor)
                .frame(width: 7, height: 7)
            Text(category.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
        }
        .foregroundColor(isSelected ? .white : .primary)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            Capsule().fill(isSelected ? category.swiftUIColor : category.swiftUIColor.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(
                isSelected ? Color.clear : category.swiftUIColor.opacity(0.30),
                lineWidth: 1
            )
        )
        .contentShape(Capsule())
        .onTapGesture { action() }
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
    }
}
