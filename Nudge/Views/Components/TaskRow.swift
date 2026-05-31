import SwiftUI

enum TaskRowStyle {
    case list
    case card
}

struct TaskRow: View {
    let task: TaskItem
    var style: TaskRowStyle = .list
    var accent: Color = AppTheme.accent
    var onToggle: () -> Void

    @State private var justCompleted = false
    @State private var checkScale: CGFloat = 1

    private var dueLabel: String? {
        guard let dueDate = task.dueDate else { return nil }
        if Calendar.current.isDateInToday(dueDate) { return "Today" }
        if Calendar.current.isDateInTomorrow(dueDate) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dueDate)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return AppTheme.overdue
        case .medium: return AppTheme.accent
        case .low: return AppTheme.sky
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                let completing = !task.isCompleted
                if completing {
                    justCompleted = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        checkScale = 1.35
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            checkScale = 1
                        }
                        justCompleted = false
                    }
                }
                onToggle()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(
                            task.isCompleted ? AppTheme.success : accent.opacity(0.35),
                            lineWidth: 2
                        )
                        .frame(width: 26, height: 26)

                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(AppTheme.success)
                            .clipShape(Circle())
                            .scaleEffect(checkScale)
                    }
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: justCompleted)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(task.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .strikethrough(task.isCompleted, color: AppTheme.textSecondary)
                    .animation(.easeOut(duration: 0.25), value: task.isCompleted)

                HStack(spacing: 8) {
                    if task.isOverdue {
                        statusChip("Overdue", color: AppTheme.overdue, icon: "exclamationmark.circle.fill")
                    } else if let dueLabel {
                        statusChip(dueLabel, color: AppTheme.textSecondary, icon: "calendar")
                    }

                    if task.priority == .high {
                        statusChip("Focus", color: priorityColor, icon: "bolt.fill")
                    }
                }
            }

            Spacer(minLength: 0)

            Circle()
                .fill(priorityColor.opacity(0.85))
                .frame(width: 8, height: 8)
                .opacity(task.isCompleted ? 0.2 : 1)
        }
        .padding(style == .card ? 14 : 0)
        .background(style == .card ? AppTheme.cardBackground : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: style == .card ? 16 : 0, style: .continuous))
        .shadow(color: style == .card ? AppTheme.cardShadow : .clear, radius: 8, y: 3)
        .bounceScale(trigger: justCompleted)
    }

    private func statusChip(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
