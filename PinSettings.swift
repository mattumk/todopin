import Foundation

/// Préférences persistantes du PIN (rayon des ondes, etc.)
final class PinSettings: ObservableObject {
    static let shared = PinSettings()

    private let scaleKey = "com.todopin.pulseScale"

    @Published var pulseScale: Double {
        didSet { UserDefaults.standard.set(pulseScale, forKey: scaleKey) }
    }

    private init() {
        let saved = UserDefaults.standard.double(forKey: scaleKey)
        pulseScale = saved > 0 ? saved : 2.1
    }
}
