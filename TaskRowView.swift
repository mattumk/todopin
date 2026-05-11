import SwiftUI

struct TaskRowView: View {
    let task: Task
    @ObservedObject var taskManager: TaskManager

    @State private var hovered      = false
    @State private var isEditing    = false
    @State private var editTitle    = ""
    @State private var editDueDate  = Date()
    @State private var editHasDue   = false
    @FocusState private var editFocused: Bool

    // ── Animation de complétion ────────────────────────────────────────
    @State private var completing  = false   // true pendant la seconde d'animation
    @State private var showBurst   = false   // déclenche le burst de particules

    // ── Note ───────────────────────────────────────────────────────────
    @State private var showNote    = false   // commentaire déplié
    @State private var editNote    = ""

    private var isVisuallyCompleted: Bool { task.isCompleted || completing }

    /// Tâche créée aujourd'hui dont l'heure est passée → badge rouge
    private var isOverdue: Bool {
        guard let due = task.dueDate else { return false }
        return !isVisuallyCompleted && due < Date() && Calendar.current.isDateInToday(task.date)
    }

    /// Tâche créée un jour précédent non reportée → badge orange
    private var isVeryOverdue: Bool {
        guard task.dueDate != nil else { return false }
        return !isVisuallyCompleted && !Calendar.current.isDateInToday(task.date)
    }

    var body: some View {
        Group {
            if isEditing {
                editRow
            } else {
                normalRow
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    isEditing ? UmakeTheme.navy.opacity(0.09) :
                    hovered   ? Color(NSColor.controlBackgroundColor).opacity(1.0) :
                                Color(NSColor.controlBackgroundColor).opacity(0.95)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(
                            isEditing    ? UmakeTheme.navy.opacity(0.28) :
                            completing   ? UmakeTheme.orange.opacity(0.35) :
                            hovered      ? UmakeTheme.navy.opacity(0.22) :
                                           Color.primary.opacity(0.10),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(hovered ? 0.10 : 0.05),
                    radius: hovered ? 8 : 3,
                    x: 0,
                    y: hovered ? 3 : 1
                )
        )
        // ── Barre de tag colorée à gauche ─────────────────────────────
        .overlay(alignment: .leading) {
            if let cat = taskManager.category(for: task) {
                Capsule()
                    .fill(cat.swiftUIColor)
                    .frame(width: 3)
                    .padding(.vertical, 8)
                    .padding(.leading, 5)
            }
        }
        .onHover { v in if !isEditing && !completing { hovered = v } }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditing)
        .animation(.easeInOut(duration: 0.12), value: hovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: completing)
    }

    // MARK: - Normal row

    private var normalRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Ligne principale ────────────────────────────────────────
            HStack(spacing: 12) {
                checkButton
                label
                Spacer(minLength: 0)
                // Crayon (modifier)
                editButton
                    .opacity(hovered && !completing ? 1 : 0)
                    .animation(.easeInOut(duration: 0.12), value: hovered)
                // Croix (supprimer)
                deleteButton
                    .opacity(hovered && !completing ? 1 : 0)
                    .animation(.easeInOut(duration: 0.12), value: hovered)
            }
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, showNote && !task.note.isEmpty ? 5 : 11)

            // ── Commentaire déplié ──────────────────────────────────────
            if showNote && !task.note.isEmpty {
                Text(task.note)
                    .font(.system(size: 12))
                    .foregroundStyle(AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 48)   // aligné avec le titre (22 checkbox + 12 gap + 14 padding)
                    .padding(.trailing, 14)
                    .padding(.bottom, 11)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Clic n'importe où sur la brique → déplie le commentaire s'il y en a un
            guard !task.note.isEmpty, !isEditing, !completing else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                showNote.toggle()
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: showNote)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisuallyCompleted)
    }

    // MARK: - Edit row

    private var editRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Titre de la tâche", text: $editTitle)
                        .font(.system(size: 14))
                        .textFieldStyle(.plain)
                        .focused($editFocused)
                        .onSubmit { saveEdit() }
                    TextField("Commentaire…", text: $editNote)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .textFieldStyle(.plain)
                }
            }
            HStack(spacing: 0) {
                Spacer().frame(width: 34)
                QuickDatePicker(date: $editDueDate, hasDate: $editHasDue)
                Spacer()
            }
            HStack(spacing: 8) {
                Spacer().frame(width: 34)
                Text("Annuler")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.10)))
                    .contentShape(Rectangle())
                    .onTapGesture { cancelEdit() }
                Text("Enregistrer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(UmakeTheme.navy))
                    .contentShape(Rectangle())
                    .onTapGesture { saveEdit() }
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Checkbox

    private var checkButton: some View {
        ZStack {
            // Cercle de fond
            Circle()
                .strokeBorder(
                    isVisuallyCompleted ? UmakeTheme.orange : UmakeTheme.navy.opacity(0.30),
                    lineWidth: 1.5
                )
                .background(
                    Circle().fill(isVisuallyCompleted ? UmakeTheme.orange : Color.clear)
                )
                .frame(width: 22, height: 22)
                .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isVisuallyCompleted)

            // Checkmark
            if isVisuallyCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }

            // Burst de particules
            if showBurst {
                ConfettiBurst(color: UmakeTheme.orange)
                    .frame(width: 64, height: 64)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 22, height: 22)
        .contentShape(Circle())
        .onTapGesture { handleCheckTap() }
    }

    private func handleCheckTap() {
        if task.isCompleted {
            // Décocher immédiatement
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                taskManager.toggle(task)
            }
        } else if !completing {
            // 1. Afficher l'état "coché" visuellement
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                completing = true
            }
            // 2. Burst de particules
            showBurst = true

            // 3. Après 1 seconde : valider et laisser la brique disparaître
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
                    taskManager.toggle(task)
                }
                completing  = false
                showBurst   = false
            }
        }
    }

    // MARK: - Label

    private var label: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(task.title)
                    .font(.system(size: 14))
                    .foregroundStyle(isVisuallyCompleted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .strikethrough(isVisuallyCompleted, color: .secondary.opacity(0.55))
                    .lineLimit(2)
                // Petite icône indiquant qu'il y a un commentaire
                if !task.note.isEmpty && !isVisuallyCompleted {
                    Image(systemName: showNote ? "bubble.left.fill" : "bubble.left")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }

            // ── Badges en ligne (tag + échéance) ──────────────────────
            let cat = taskManager.category(for: task)
            let hasBadges = cat != nil || (task.dueDate != nil && !isVisuallyCompleted)
            if hasBadges {
                HStack(spacing: 5) {
                    if let cat = cat, !isVisuallyCompleted {
                        tagBadge(cat)
                    }
                    if let due = task.dueDate, !isVisuallyCompleted {
                        dueBadge(due)
                    }
                }
            }
        }
    }

    private func tagBadge(_ cat: TaskCategory) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(cat.swiftUIColor)
                .frame(width: 5, height: 5)
            Text(cat.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(cat.swiftUIColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(cat.swiftUIColor.opacity(0.12)))
    }

    private func dueBadge(_ due: Date) -> some View {
        HStack(spacing: 3) {
            Image(systemName: (isOverdue || isVeryOverdue) ? "exclamationmark.clock" : "clock")
                .font(.system(size: 10, weight: .medium))
            Text(dueLabel(due))
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(isVeryOverdue ? UmakeTheme.orange : isOverdue ? UmakeTheme.red : .secondary)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(
            Capsule().fill(
                isVeryOverdue ? UmakeTheme.orange.opacity(0.12) :
                isOverdue     ? UmakeTheme.red.opacity(0.10)    :
                                UmakeTheme.navy.opacity(0.06)
            )
        )
    }

    // MARK: - Edit button (crayon)

    private var editButton: some View {
        Image(systemName: "pencil")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 22)
            .background(Circle().fill(Color.secondary.opacity(0.10)))
            .contentShape(Circle())
            .onTapGesture { startEditing() }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Image(systemName: "xmark")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 22)
            .background(Circle().fill(Color.secondary.opacity(0.10)))
            .contentShape(Circle())
            .onTapGesture { taskManager.delete(task) }
    }

    // MARK: - Edit helpers

    private func startEditing() {
        guard !task.isCompleted && !completing else { return }
        editTitle   = task.title
        editNote    = task.note
        editDueDate = task.dueDate ?? nearestHour()
        editHasDue  = task.dueDate != nil
        isEditing   = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            editFocused = true
        }
    }

    private func saveEdit() {
        let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { cancelEdit(); return }
        taskManager.update(task.id, title: trimmed, note: editNote, dueDate: editHasDue ? editDueDate : nil)
        isEditing = false
    }

    private func cancelEdit() { isEditing = false }

    private func nearestHour() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
        comps.hour = (comps.hour ?? 0) + 1
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func dueLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        if Calendar.current.isDateInToday(date)          { f.dateFormat = "HH:mm" }
        else if Calendar.current.isDateInYesterday(date) { f.dateFormat = "'Hier' HH:mm" }
        else if Calendar.current.isDateInTomorrow(date)  { f.dateFormat = "'Demain' HH:mm" }
        else                                              { f.dateFormat = "d MMM HH:mm" }
        return f.string(from: date)
    }
}

// MARK: - Burst de particules

private struct ConfettiBurst: View {
    let color: Color
    @State private var phase: CGFloat = 0

    private let count = 8

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                particle(index: i)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.58)) { phase = 1 }
        }
    }

    private func particle(index i: Int) -> some View {
        let angle:  Double  = (Double.pi * 2 / Double(count)) * Double(i) - Double.pi / 2
        let radius: CGFloat = (i % 2 == 0) ? 28 : 22
        let size:   CGFloat = (i % 3 == 0) ? 5  : 3.5
        let fill:   Color   = (i % 2 == 0) ? color : color.opacity(0.65)
        let opac:   Double  = phase < 0.45 ? 1.0 : max(0, 1.0 - (phase - 0.45) / 0.55)

        return Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .offset(x: cos(angle) * radius * phase,
                    y: sin(angle) * radius * phase)
            .opacity(opac)
            .scaleEffect(max(0.01, 1.0 - 0.5 * phase))
    }
}
