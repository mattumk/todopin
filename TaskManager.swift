import Foundation
import Combine

class TaskManager: ObservableObject {
    static let shared = TaskManager()

    @Published private(set) var tasks:      [Task]         = []
    @Published private(set) var categories: [TaskCategory] = []

    private let storageKey    = "com.todopin.tasks"
    private let categoriesKey = "com.todopin.categories"
    private var timer: Timer?

    private init() {
        load()
        loadCategories()
        // Réévalue les échéances chaque minute (badge, pulsation)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Computed

    var todayTasks: [Task] {
        tasks.filter { task in
            // Tâche non complétée → toujours visible jusqu'à ce qu'elle soit faite
            if !task.isCompleted { return true }
            // Tâche complétée → visible seulement si cochée aujourd'hui
            if let completed = task.completedDate {
                return Calendar.current.isDateInToday(completed)
            }
            // Fallback pour les tâches sans completedDate (ancien format)
            return Calendar.current.isDateInToday(task.date)
        }
    }

    /// Tâches non complétées, dans l'ordre manuel défini par l'utilisateur
    var todayPending: [Task] {
        todayTasks
            .filter { !$0.isCompleted }
            .sorted { $0.order < $1.order }
    }

    var todayCompleted: [Task] {
        todayTasks.filter { $0.isCompleted }
    }

    var pendingCount: Int { todayPending.count }

    /// Catégories qui ont au moins une tâche pending aujourd'hui, triées par ordre manuel
    var activeCategories: [TaskCategory] {
        let usedIds = Set(todayPending.compactMap { $0.categoryId })
        return categories
            .filter { usedIds.contains($0.id) }
            .sorted { $0.order < $1.order }
    }

    func reorderCategories(ids: [UUID]) {
        for (index, id) in ids.enumerated() {
            if let i = categories.firstIndex(where: { $0.id == id }) {
                categories[i].order = index
            }
        }
        persistCategories()
    }

    func pendingTasks(for category: TaskCategory) -> [Task] {
        todayPending.filter { $0.categoryId == category.id }
    }

    var uncategorizedPending: [Task] {
        todayPending.filter { $0.categoryId == nil }
    }

    func category(for task: Task) -> TaskCategory? {
        guard let id = task.categoryId else { return nil }
        return categories.first { $0.id == id }
    }

    /// Tâches d'aujourd'hui dont le dueDate est avant minuit → pulsation orange
    /// (inclut les tâches reportées depuis hier)
    /// NB : seules les todayTasks comptent — les anciennes tâches invisibles n'affectent pas le pin
    var hasVeryOverdueTasks: Bool {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return todayTasks.filter { !$0.isCompleted }.contains { task in
            guard let due = task.dueDate else { return false }
            return due < startOfToday
        }
    }

    /// Tâches d'aujourd'hui dont l'heure est passée (dans la journée) → pulsation bleue
    var hasNowDueTasks: Bool {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return todayTasks.filter { !$0.isCompleted }.contains { task in
            guard let due = task.dueDate else { return false }
            return due >= startOfToday && due <= now
        }
    }

    func yesterdayIncompleteTasks() -> [Task] {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return [] }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return tasks.filter {
            // Créée hier, non complétée
            guard Calendar.current.isDate($0.date, inSameDayAs: yesterday) && !$0.isCompleted
            else { return false }
            // Exclure les tâches planifiées pour aujourd'hui ou plus tard (pas en retard)
            if let due = $0.dueDate, due >= startOfToday { return false }
            return true
        }
    }

    // MARK: - Actions

    func add(title: String, note: String = "", dueDate: Date? = nil, categoryId: UUID? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (tasks.map { $0.order }.max() ?? -1) + 1
        var task = Task(title: trimmed, note: note, dueDate: dueDate)
        task.order      = nextOrder
        task.categoryId = categoryId
        tasks.append(task)
        persist()
    }

    // MARK: - Catégories

    @discardableResult
    func addCategory(name: String, color: String) -> TaskCategory {
        let cat = TaskCategory(name: name, color: color)
        categories.append(cat)
        persistCategories()
        return cat
    }

    func deleteCategory(_ category: TaskCategory) {
        for i in tasks.indices where tasks[i].categoryId == category.id {
            tasks[i].categoryId = nil
        }
        categories.removeAll { $0.id == category.id }
        persist()
        persistCategories()
    }

    func assignCategory(_ categoryId: UUID?, to taskId: UUID) {
        mutate(taskId) { $0.categoryId = categoryId }
    }

    /// Réordonne les tâches pending suite à un drag-to-reorder (List onMove)
    func movePendingTasks(from: IndexSet, to: Int) {
        var pending = todayPending
        pending.move(fromOffsets: from, toOffset: to)
        for (index, task) in pending.enumerated() {
            if let i = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[i].order = index
            }
        }
        persist()
    }

    /// Réordonne les tâches pending à partir d'un tableau d'IDs ordonnés (drag custom)
    func reorderPendingTasks(ids: [UUID]) {
        for (index, id) in ids.enumerated() {
            if let i = tasks.firstIndex(where: { $0.id == id }) {
                tasks[i].order = index
            }
        }
        persist()
    }

    func toggle(_ task: Task) {
        mutate(task.id) {
            $0.isCompleted.toggle()
            $0.completedDate = $0.isCompleted ? Date() : nil
        }
    }

    func update(_ id: UUID, title: String, note: String, dueDate: Date?) {
        mutate(id) {
            $0.title   = title.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.note    = note
            $0.dueDate = dueDate
        }
    }

    func delete(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        persist()
    }

    func rollover(_ old: [Task]) {
        // 1. Compléter les originaux d'hier pour qu'ils n'alimentent plus les indicateurs
        for task in old {
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].isCompleted = true
            }
        }
        // 2. Créer les copies d'aujourd'hui (anti-doublon par titre)
        let existingTitles = Set(todayTasks.map { $0.title.lowercased() })
        let new = old
            .filter { !existingTitles.contains($0.title.lowercased()) }
            .map    { Task(title: $0.title, note: $0.note, dueDate: $0.dueDate) }
        if !new.isEmpty { tasks.append(contentsOf: new) }
        persist()
    }

    // MARK: - Rollover memory (évite le double popup au relancement)

    private let rolloverShownKey = "com.todopin.rolloverShownDate"

    /// Vrai si le popup de rollover a déjà été affiché aujourd'hui (quelle que soit la réponse)
    func wasRolloverShownToday() -> Bool {
        guard let stored = UserDefaults.standard.string(forKey: rolloverShownKey)
        else { return false }
        return stored == todayString()
    }

    /// Marque le popup comme affiché aujourd'hui
    func markRolloverShown() {
        UserDefaults.standard.set(todayString(), forKey: rolloverShownKey)
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Private

    private func mutate(_ id: UUID, _ mutation: (inout Task) -> Void) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        mutation(&tasks[idx])
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Task].self, from: data)
        else { return }
        tasks = decoded
    }

    private func persistCategories() {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        UserDefaults.standard.set(data, forKey: categoriesKey)
    }

    private func loadCategories() {
        guard
            let data = UserDefaults.standard.data(forKey: categoriesKey),
            let decoded = try? JSONDecoder().decode([TaskCategory].self, from: data)
        else { return }
        categories = decoded
    }
}
