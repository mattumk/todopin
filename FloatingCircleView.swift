import SwiftUI

struct FloatingCircleView: View {
    @ObservedObject var taskManager: TaskManager
    @ObservedObject var pinState:    FloatingPinState   // piloté par FloatingPanelContent

    var onHoverStart: () -> Void
    var onHoverEnd:   () -> Void

    var count:         Int  { taskManager.pendingCount }
    var hasPending:    Bool { count > 0 }
    var isVeryOverdue: Bool { taskManager.hasVeryOverdueTasks }
    var isNowDue:      Bool { taskManager.hasNowDueTasks }

    var body: some View {
        ZStack {
            // — Ondes —
            if isVeryOverdue {
                PulseRing(color: .orange,      delay: 0.0,  duration: 1.0)
                PulseRing(color: .orange,      delay: 0.5,  duration: 1.0)
            } else if isNowDue {
                PulseRing(color: .accentColor, delay: 0.0,  duration: 1.8)
                PulseRing(color: .accentColor, delay: 0.9,  duration: 1.8)
            }

            // — Cercle —
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 56, height: 56)
                .overlay(
                    Circle().strokeBorder(
                        isVeryOverdue ? Color.orange.opacity(0.9)
                            : isNowDue ? Color.accentColor.opacity(0.85)
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
                        .foregroundColor(isVeryOverdue ? .orange : .primary)
                        .contentTransition(.numericText())
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
        }
        .frame(width: 128, height: 128)
        // Le tap et le drag sont gérés par FloatingPanelContent (AppKit)
        // .onHover reste en SwiftUI : il utilise NSTrackingArea, indépendant de mouseDown
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
    @State private var animating = false

    var body: some View {
        Circle()
            .strokeBorder(color.opacity(animating ? 0 : 0.5), lineWidth: 1.5)
            .frame(width: 56, height: 56)
            .scaleEffect(animating ? 2.1 : 1.0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                        animating = true
                    }
                }
            }
    }
}
