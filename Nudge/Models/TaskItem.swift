import Foundation
import SwiftData

enum TaskPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var label: String {
        rawValue.capitalized
    }
}

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var notes: String?
    var priorityRaw: String
    var dueDate: Date?
    var reminderDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    init(
        title: String,
        notes: String? = nil,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        reminderDate: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.priorityRaw = priority.rawValue
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.isCompleted = false
        self.createdAt = Date()
        self.completedAt = nil
    }

    var isOverdue: Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    var isDueToday: Bool {
        guard !isCompleted, let dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    func markComplete() {
        isCompleted = true
        completedAt = Date()
    }
}
