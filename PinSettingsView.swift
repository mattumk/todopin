import SwiftUI

struct PinSettingsView: View {
    @ObservedObject private var settings = PinSettings.shared

    // Palette étendue : mêmes couleurs que les catégories
    private let palette: [String] = TaskCategory.palette

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Couleur du PIN ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 12) {
                Label("Couleur du PIN", systemImage: "circle.fill")
                    .font(.system(size: 13, weight: .semibold))

                // Grille 5 colonnes : défaut + 8 couleurs
                let columns = Array(repeating: GridItem(.fixed(30), spacing: 8), count: 5)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    defaultButton
                    ForEach(palette, id: \.self) { hex in
                        colorButton(hex: hex)
                    }
                }
            }

            Divider()

            // ── Ondes ──────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Label("Rayon des ondes", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 12) {
                    Image(systemName: "circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Slider(value: $settings.pulseScale, in: 1.3...3.5, step: 0.1)
                        .accentColor(currentColor ?? UmakeTheme.orange)
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
                    withAnimation {
                        settings.pulseScale = 2.1
                        settings.pinColor   = nil
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 300, height: 320)
    }

    // MARK: - Couleur active

    private var currentColor: Color? {
        guard let hex = settings.pinColor else { return nil }
        return Color(hex: hex)
    }

    // MARK: - Bouton défaut (verre)

    private var defaultButton: some View {
        let isSelected = settings.pinColor == nil
        return ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 28, height: 28)
            if isSelected {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.7), lineWidth: 2)
                    .frame(width: 28, height: 28)
            }
            Image(systemName: "circle.dotted")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(width: 28, height: 28)
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) { settings.pinColor = nil }
        }
        .help("Défaut (verre)")
    }

    // MARK: - Bouton couleur

    private func colorButton(hex: String) -> some View {
        let isSelected = settings.pinColor == hex
        let color = Color(hex: hex) ?? .gray
        return Circle()
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay(
                Circle().strokeBorder(
                    isSelected ? Color.primary.opacity(0.7) : Color.clear,
                    lineWidth: 2
                )
            )
            .contentShape(Circle())
            .onTapGesture {
                withAnimation(.spring(response: 0.2)) { settings.pinColor = hex }
            }
            .help(hex)
    }
}
