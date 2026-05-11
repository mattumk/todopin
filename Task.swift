import Foundation

struct Task: Codable, Identifiable, Equatable {
    var id      = UUID()
    var title:  String
    var note:   String  = ""
    var isCompleted: Bool = false
    var date:          Date  = Date()  // date de création
    var completedDate: Date? = nil    // date de complétion (nil = pas encore faite)
    var dueDate:       Date? = nil    // échéance optionnelle
    var order:         Int   = 0      // ordre manuel (drag-to-reorder)
    var categoryId:    UUID? = nil    // catégorie optionnelle
}
