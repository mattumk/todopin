import SwiftUI

/// Tooltip transparent qui apparaît sous le pin au survol
struct TaskPreviewView: View {
    let tasks: [Task]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(tasks) { task in
                HStack(spacing: 8) {
                    Circle()
                        .fill(dotColor(for: task))
                        .frame(width: 5, height: 5)

                    Text(task.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if let due = task.dueDate {
                        Text(dueLabel(due))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(labelColor(for: due))
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 230)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(UmakeTheme.navy.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func dotColor(for task: Task) -> Color {
        guard let due = task.dueDate else { return UmakeTheme.navy.opacity(0.25) }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        if due < startOfToday { return UmakeTheme.orange }
        return due <= Date() ? UmakeTheme.navy : UmakeTheme.navy.opacity(0.25)
    }

    private func labelColor(for due: Date) -> Color {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        if due < startOfToday { return UmakeTheme.orange }
        if due <= Date()      { return .primary          }
        return .secondary
    }

    private func dueLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        if Calendar.current.isDateInToday(date) {
            f.dateFormat = "HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            f.dateFormat = "'Hier' HH:mm"
        } else {
            f.dateFormat = "d MMM HH:mm"
        }
        return f.string(from: date)
    }
}
