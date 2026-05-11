import SwiftUI

struct PinSettingsView: View {
    @ObservedObject private var settings = PinSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Ondes ──────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Label("Ondes du PIN", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Image(systemName: "circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Slider(value: $settings.pulseScale, in: 1.3...3.5, step: 0.1)
                        .accentColor(UmakeTheme.orange)

                    Image(systemName: "circle.dotted")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Text("Rayon : \(String(format: "%.1f", settings.pulseScale))×")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Divider()

            // ── Reset ───────────────────────────────────────────────────
            HStack {
                Spacer()
                Button("Réinitialiser") {
                    withAnimation { settings.pulseScale = 2.1 }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
