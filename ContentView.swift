import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var taskManager: TaskManager

    @State private var newTitle            = ""
    @State private var newNote             = ""
    @State private var selectedDue         = Date()
    @State private var hasDue              = false
    @State private var showCompleted       = false
    @State private var selectedCategoryId: UUID? = nil
    @State private var addFieldExpanded    = false
    @State private var filterCategoryId:   UUID? = nil
    @State private var showTagFilter       = false
    @FocusState private var inputFocused: Bool

    private var pending:  [Task] { taskManager.todayPending }
    private var completed:[Task] { taskManager.todayCompleted }
    private var allToday: [Task] { taskManager.todayTasks }

    private var filteredPending: [Task] {
        guard let catId = filterCategoryId else { return pending }
        return pending.filter { $0.categoryId == catId }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                addField
                taskList
            }
            .background(
                Color(NSColor.windowBackgroundColor)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissAddField() }
            )

            // ── Raccourcis clavier invisibles ──────────────────────────────
            Button("") { NSApp.keyWindow?.orderOut(nil) }
                .keyboardShortcut(.escape, modifiers: [])
                .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)

            Button("") { inputFocused = true }
                .keyboardShortcut("n", modifiers: [.command])
                .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)
        }
        .frame(width: 400, height: 600)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(todayLabel())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text("Aujourd'hui")
                    .font(.system(size: 26, weight: .bold))
            }
            Spacer()
            // ── Filtre par tag ────────────────────────────────────────
            Button {
                showTagFilter.toggle()
            } label: {
                Image(systemName: filterCategoryId != nil ? "tag.fill" : "tag")
                    .font(.system(size: 13))
                    .foregroundColor(filterCategoryId != nil ? UmakeTheme.orange : .secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Filtrer par tag")
            .popover(isPresented: $showTagFilter, arrowEdge: .bottom) {
                TagFilterPopover(taskManager: taskManager, filterCategoryId: $filterCategoryId)
            }

            // ── Engrenage paramètres ──────────────────────────────────
            Button {
                (NSApp.delegate as? AppDelegate)?.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Paramètres")

            progressRing
        }
        .padding(.horizontal, 26)
        .padding(.top, 30)
        .padding(.bottom, 20)
    }

    private var progressRing: some View {
        let total = allToday.count
        let done  = completed.count
        let ratio = total > 0 ? Double(done) / Double(total) : 0.0
        let count = taskManager.pendingCount

        return ZStack {
            Circle()
                .stroke(UmakeTheme.navy.opacity(0.10), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(
                    LinearGradient(
                        colors: [UmakeTheme.orange, UmakeTheme.navy],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: ratio)
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: count > 9 ? 12 : 14, weight: .bold))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: count)
        }
        .frame(width: 48, height: 48)
    }

    // MARK: - Add field

    private var addField: some View {
        VStack(spacing: 0) {
            // ── Ligne titre ───────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 19))
                    .foregroundColor(UmakeTheme.orange)

                TextField("Nouvelle tâche… (⌘N)", text: $newTitle)
                    .font(.system(size: 15))
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .onSubmit { submit() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 13)
            .padding(.bottom, addFieldExpanded ? 4 : 13)
            .onChange(of: inputFocused) { focused in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    addFieldExpanded = focused || !newTitle.isEmpty
                }
            }
            .onChange(of: newTitle) { text in
                if !addFieldExpanded && !text.isEmpty {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        addFieldExpanded = true
                    }
                }
            }

            // ── Commentaire + options (visibles uniquement quand le champ est actif) ──
            if addFieldExpanded {
                // Champ commentaire
                HStack(spacing: 10) {
                    Spacer().frame(width: 29)   // aligne avec le texte du titre
                    TextField("Ajouter un commentaire…", text: $newNote)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .textFieldStyle(.plain)
                        .onSubmit { submit() }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                Divider()
                    .background(UmakeTheme.navy.opacity(0.08))
                    .padding(.horizontal, 14)
                QuickDatePicker(date: $selectedDue, hasDate: $hasDue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Divider()
                    .background(UmakeTheme.navy.opacity(0.08))
                    .padding(.horizontal, 14)
                CategoryPickerView(taskManager: taskManager, selectedCategoryId: $selectedCategoryId)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(UmakeTheme.navy.opacity(0.05)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(UmakeTheme.navy.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Task list

    /// Retire le focus du champ de saisie (ferme les options d'ajout)
    private func dismissAddField() {
        inputFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private var taskList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            let tasks = filteredPending
            if tasks.isEmpty && completed.isEmpty {
                emptyState.padding(.top, 8)
            } else {
                VStack(spacing: 0) {
                    // ── Tâches pending ──────────────────────────────────────
                    if !tasks.isEmpty {
                        if filterCategoryId != nil {
                            // Filtre actif : liste simple (pas de reorder, ça n'a pas de sens sur un sous-ensemble)
                            VStack(spacing: 6) {
                                ForEach(tasks) { task in
                                    TaskRowView(task: task, taskManager: taskManager)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tasks.map(\.id))
                        } else {
                            // Pas de filtre : liste reorderable
                            ReorderableTaskList(taskManager: taskManager, tasks: pending)
                        }
                    }

                    // ── Tâches traitées ─────────────────────────────────────
                    if !completed.isEmpty {
                        completedHeader.padding(.horizontal, 20)
                        if showCompleted {
                            VStack(spacing: 6) {
                                ForEach(completed) { task in
                                    TaskRowView(task: task, taskManager: taskManager)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 4)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: completed.map(\.id))
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: pending.map(\.id))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: completed.map(\.id))
        .simultaneousGesture(TapGesture().onEnded { dismissAddField() })
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: emptyStateIcon())
                .font(.system(size: 36))
                .foregroundColor(UmakeTheme.orange.opacity(0.45))
            Text(emptyStateMessage())
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 52)
    }

    // En-tête déroulant "Traitées"
    private var completedHeader: some View {
        HStack(spacing: 6) {
            Text("Traitées")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase).tracking(0.8)
            Text("(\(completed.count))")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
            Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showCompleted.toggle()
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    // MARK: - Helpers

    private func submit() {
        taskManager.add(title: newTitle,
                        note: newNote,
                        dueDate: hasDue ? selectedDue : nil,
                        categoryId: selectedCategoryId)
        newTitle = ""; newNote = ""; hasDue = false; selectedCategoryId = nil
        inputFocused = true
    }

    private func todayLabel() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: Date()).capitalized
    }

    private func emptyStateMessage() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Bonne matinée !"
        case 12..<14: return "Bon appétit !"
        case 14..<18: return "Bonne après-midi !"
        case 18..<22: return "Bonne soirée !"
        default:      return "Bonne nuit !"
        }
    }

    private func emptyStateIcon() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "sun.horizon"
        case 12..<14: return "fork.knife"
        case 14..<18: return "sun.max"
        case 18..<22: return "moon.stars"
        default:      return "zzz"
        }
    }
}

// MARK: - Popover filtre par tag

private struct TagFilterPopover: View {
    @ObservedObject var taskManager: TaskManager
    @Binding var filterCategoryId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Titre
            Text("Filtrer par tag")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.bottom, 10)

            // "Tous" — remet à zéro le filtre
            filterRow(
                color: .secondary,
                name: "Tous les tags",
                isSelected: filterCategoryId == nil,
                icon: "tag"
            ) {
                filterCategoryId = nil
            }

            if !taskManager.categories.isEmpty {
                Divider().padding(.vertical, 6)

                ForEach(taskManager.categories) { cat in
                    filterRow(
                        color: cat.swiftUIColor,
                        name: cat.name,
                        isSelected: filterCategoryId == cat.id,
                        icon: nil
                    ) {
                        filterCategoryId = filterCategoryId == cat.id ? nil : cat.id
                    }
                }
            }
        }
        .padding(14)
        .frame(minWidth: 190)
    }

    private func filterRow(
        color: Color,
        name: String,
        isSelected: Bool,
        icon: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 14)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .frame(width: 14)
            }
            Text(name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected && icon != nil ? .white : color)
            }
        }
        .foregroundColor(isSelected ? (icon != nil ? .white : color) : .primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? (icon != nil ? UmakeTheme.navy : color.opacity(0.12)) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                action()
            }
        }
    }
}
