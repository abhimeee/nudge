import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    var onToggle: () -> Void

    private var dueLabel: String? {
        guard let dueDate = task.dueDate else { return nil }
        if Calendar.current.isDateInToday(dueDate) { return "Today" }
        if Calendar.current.isDateInTomorrow(dueDate) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dueDate)
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? AppTheme.success : AppTheme.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(task.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .strikethrough(task.isCompleted)

                HStack(spacing: 8) {
                    if task.isOverdue {
                        Text("Overdue")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.overdue)
                    } else if let dueLabel {
                        Text(dueLabel)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    if task.priority == .high {
                        Text("High")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accentMuted)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
