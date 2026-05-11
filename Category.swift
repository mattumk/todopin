import SwiftUI

struct TaskCategory: Codable, Identifiable, Equatable {
    var id    = UUID()
    var name:  String
    var color: String   // hex "#RRGGBB"
    var order: Int = 0

    var swiftUIColor: Color { Color(hex: color) ?? .gray }

    // Palette proposée à la création
    static let palette: [String] = [
        "#F6A24A", // orange Umake
        "#4CAF82", // vert
        "#7C5CBF", // violet
        "#E85D8A", // rose
        "#FF5565", // rouge Umake
        "#2BA5B0", // teal
        "#E8C54A", // jaune
        "#5B9BD5", // bleu ciel
    ]

    static func randomColor(excluding used: [String] = []) -> String {
        let available = palette.filter { !used.contains($0) }
        return (available.isEmpty ? palette : available).randomElement() ?? palette[0]
    }
}

// MARK: - Color ↔ Hex

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&int) else { return nil }
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >>  8) & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}
