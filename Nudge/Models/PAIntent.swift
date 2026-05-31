import Foundation

struct PAIntent: Decodable {
    let intent: String
    let reply: String
    let tasks: [ParsedTask]?
    let taskId: String?
    let checkInSummary: String?

    init(intent: String, reply: String, tasks: [ParsedTask]? = nil, taskId: String? = nil, checkInSummary: String? = nil) {
        self.intent = intent
        self.reply = reply
        self.tasks = tasks
        self.taskId = taskId
        self.checkInSummary = checkInSummary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intent = try container.decodeIfPresent(String.self, forKey: .intent)
            ?? container.decodeIfPresent(String.self, forKey: .action)
            ?? "query_tasks"
        reply = try container.decodeIfPresent(String.self, forKey: .reply)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? "Done."
        tasks = try container.decodeIfPresent([ParsedTask].self, forKey: .tasks)
        taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
            ?? container.decodeIfPresent(String.self, forKey: .task_id)
        checkInSummary = try container.decodeIfPresent(String.self, forKey: .checkInSummary)
            ?? container.decodeIfPresent(String.self, forKey: .check_in_summary)
    }

    private enum CodingKeys: String, CodingKey {
        case intent, action, reply, message, tasks, taskId, task_id, checkInSummary, check_in_summary
    }
}

struct ParsedTask: Decodable {
    let title: String
    let dueAt: String?
    let priority: String?
    let reminderAt: String?

    init(title: String, dueAt: String? = nil, priority: String? = nil, reminderAt: String? = nil) {
        self.title = title
        self.dueAt = dueAt
        self.priority = priority
        self.reminderAt = reminderAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        dueAt = try container.decodeIfPresent(String.self, forKey: .dueAt)
            ?? container.decodeIfPresent(String.self, forKey: .due_at)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
        reminderAt = try container.decodeIfPresent(String.self, forKey: .reminderAt)
            ?? container.decodeIfPresent(String.self, forKey: .reminder_at)
    }

    private enum CodingKeys: String, CodingKey {
        case title, dueAt, due_at, priority, reminderAt, reminder_at
    }
}

struct PAContext {
    let openTasks: [(id: UUID, title: String, dueDate: Date?, priority: TaskPriority)]
    let currentStreak: Int
    let checkInType: CheckInType?

    var taskSummary: String {
        guard !openTasks.isEmpty else { return "No open tasks." }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return openTasks.map { task in
            var line = "- [\(task.id.uuidString)] \(task.title)"
            if let due = task.dueDate {
                line += " (due: \(formatter.string(from: due)))"
            }
            line += " priority: \(task.priority.rawValue)"
            return line
        }.joined(separator: "\n")
    }
}

enum PAIntentAction {
    case createTask(TaskItem)
    case completeTask(UUID)
    case updateTask(UUID, ParsedTask)
    case checkIn(CheckInType, String)
    case queryOnly
}
