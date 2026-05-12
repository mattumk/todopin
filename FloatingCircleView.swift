import SwiftUI

struct FloatingCircleView: View {
    @ObservedObject var taskManager: TaskManager
    @ObservedObject var pinState:    FloatingPinState
    @ObservedObject private var pinSettings = PinSettings.shared

    var onHoverStart: () -> Void
    var onHoverEnd:   () -> Void

    var count:         Int  { taskManager.pendingCount }
    var hasPending:    Bool { count > 0 }
    var isVeryOverdue: Bool { taskManager.hasVeryOverdueTasks }
    var isNowDue:      Bool { taskManager.hasNowDueTasks }

    // ── Couleur active du pin ──────────────────────────────────────────
    private var activePinColor: Color? {
        guard let hex = pinSettings.pinColor else { return nil }
        return Color(hex: hex)
    }

    /// Couleur du texte calculée selon la luminance du fond
    private var badgeTextColor: Color {
        // Pas de couleur personnalisée → comportement normal
        guard let hex = pinSettings.pinColor else {
            return isVeryOverdue ? .orange : .primary
        }
        // Luminance perceptuelle (W3C)
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >>  8) & 0xFF) / 255.0
        let b = Double( int        & 0xFF) / 255.0
        let lum = 0.299 * r + 0.587 * g + 0.114 * b
        return lum > 0.60 ? .black : .white
    }

    /// Couleur des ondes : pin color en priorité, sinon logique overdue
    private var waveColor: Color {
        if isVeryOverdue { return .orange }
        if isNowDue      { return .accentColor }
        return activePinColor ?? Color.primary.opacity(0.4)
    }

    var body: some View {
        ZStack {
            // — Ondes —
            if isVeryOverdue {
                PulseRing(color: waveColor, delay: 0.0, duration: 1.0, scale: pinSettings.pulseScale)
                PulseRing(color: waveColor, delay: 0.5, duration: 1.0, scale: pinSettings.pulseScale)
            } else if isNowDue {
                PulseRing(color: waveColor, delay: 0.0, duration: 1.8, scale: pinSettings.pulseScale)
                PulseRing(color: waveColor, delay: 0.9, duration: 1.8, scale: pinSettings.pulseScale)
            }

            // — Cercle —
            Circle()
                .fill(activePinColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.ultraThinMaterial))
                .frame(width: 56, height: 56)
                .overlay(
                    Circle().strokeBorder(
                        isVeryOverdue    ? Color.orange.opacity(0.9)
                            : isNowDue   ? Color.accentColor.opacity(0.85)
                            : activePinColor != nil ? Color.white.opacity(0.20)
                            : Color.primary.opacity(0.18),
                        lineWidth: 1.5
                    )
                )
                .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 5)
                .scaleEffect(pinState.isPressed ? 0.88 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pinState.isPressed)

            // — Badge —
            Group {
                if hasPending {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(.system(size: count > 9 ? 16 : 22, weight: .semibold, design: .rounded))
                        .foregroundColor(badgeTextColor)
                        .contentTransition(.numericText())
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(activePinColor != nil ? badgeTextColor : .secondary)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pinSettings.pinColor)
        }
        .frame(width: 128, height: 128)
        .onHover { hovering in
            if hovering { onHoverStart() } else { onHoverEnd() }
        }
    }
}

// MARK: - Ripple

struct PulseRing: View {
    let color:    Color
    let delay:    Double
    let duration: Double
    var scale:    Double = 2.1
    @State private var animating = false

    var body: some View {
        Circle()
            .strokeBorder(color.opacity(animating ? 0 : 0.5), lineWidth: 1.5)
            .frame(width: 56, height: 56)
            .scaleEffect(animating ? scale : 1.0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                        animating = true
                    }
                }
            }
    }
}
