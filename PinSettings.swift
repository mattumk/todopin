import Foundation

/// Préférences persistantes du PIN (rayon des ondes, couleur de fond)
final class PinSettings: ObservableObject {
    static let shared = PinSettings()

    private let scaleKey = "com.todopin.pulseScale"
    private let colorKey = "com.todopin.pinColor"

    @Published var pulseScale: Double {
        didSet { UserDefaults.standard.set(pulseScale, forKey: scaleKey) }
    }

    /// nil = fond verre (défaut), hex = couleur solide
    @Published var pinColor: String? {
        didSet {
            if let c = pinColor {
                UserDefaults.standard.set(c, forKey: colorKey)
            } else {
                UserDefaults.standard.removeObject(forKey: colorKey)
            }
        }
    }

    private init() {
        let savedScale = UserDefaults.standard.double(forKey: scaleKey)
        pulseScale = savedScale > 0 ? savedScale : 2.1

        let savedColor = UserDefaults.standard.string(forKey: colorKey)
        pinColor = (savedColor?.isEmpty == false) ? savedColor : nil
    }
}
