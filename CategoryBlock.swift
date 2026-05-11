import SwiftUI

/// Bloc coloré regroupant les tâches d'une même catégorie.
struct CategoryBlock<Content: View>: View {
    let category: TaskCategory
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ── En-tête ─────────────────────────────────────────────────
            HStack(spacing: 5) {
                Circle()
                    .fill(category.swiftUIColor)
                    .frame(width: 7, height: 7)
                Text(category.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(category.swiftUIColor)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.horizontal, 4)

            // ── Tâches ──────────────────────────────────────────────────
            content()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 0)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(category.swiftUIColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(category.swiftUIColor.opacity(0.22), lineWidth: 1)
                )
        )
    }
}
