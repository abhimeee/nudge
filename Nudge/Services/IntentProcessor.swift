import Foundation
import SwiftData

enum IntentProcessor {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func sttIntent(from transcript: String) -> PAIntent {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dueToday = formatter.string(from: endOfToday())
        return PAIntent(
            intent: "create_task",
            reply: "Added to today.",
            tasks: [ParsedTask(title: cleanedTitle(from: transcript), dueAt: dueToday)]
        )
    }

    private static func cleanedTitle(from text: String) -> String {
        let cleaned = text
            .replacingOccurrences(
                of: "^(remind me to|remember to|add task|add a task|schedule|i need to|i have to)\\s*",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = cleaned.isEmpty ? text : cleaned
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    @MainActor
    static func apply(
        _ intent: PAIntent,
        userTranscript: String,
        allTasks: [TaskItem],
        checkInType: CheckInType?,
        context: ModelContext
    ) async -> [TaskItem] {
        var changedTasks: [TaskItem] = []
        var effectiveIntent = intent

        if shouldCreateTask(from: effectiveIntent, transcript: userTranscript) {
            effectiveIntent = PAIntent(
                intent: "create_task",
                reply: intent.reply,
                tasks: fallbackTasks(from: effectiveIntent, transcript: userTranscript),
                taskId: intent.taskId,
                checkInSummary: intent.checkInSummary
            )
        }

        switch effectiveIntent.intent {
        case "create_task":
            let parsedTasks = effectiveIntent.tasks ?? []
            for parsed in parsedTasks {
                let title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }
                let dueDate = parseDate(parsed.dueAt) ?? endOfToday()
                let task = TaskItem(
                    title: title,
                    priority: parsePriority(parsed.priority),
                    dueDate: dueDate,
                    reminderDate: parseDate(parsed.reminderAt) ?? dueDate
                )
                context.insert(task)
                changedTasks.append(task)
                await NotificationService.scheduleTaskReminder(for: task)
            }

        case "complete_task":
            if let task = resolveTask(id: effectiveIntent.taskId, tasks: allTasks, hint: userTranscript) {
                task.markComplete()
                NotificationService.cancelTaskReminder(for: task.id)
                changedTasks.append(task)
                AccountabilityService.recordActivity(in: context)
            }

        case "update_task":
            if let parsed = effectiveIntent.tasks?.first,
               let task = resolveTask(id: effectiveIntent.taskId, tasks: allTasks, hint: parsed.title) {
                if !parsed.title.isEmpty { task.title = parsed.title }
                if let due = parseDate(parsed.dueAt) { task.dueDate = due }
                if let reminder = parseDate(parsed.reminderAt) { task.reminderDate = reminder }
                if let priority = parsed.priority { task.priority = parsePriority(priority) }
                NotificationService.cancelTaskReminder(for: task.id)
                await NotificationService.scheduleTaskReminder(for: task)
                changedTasks.append(task)
            }

        case "check_in":
            let type = checkInType ?? .evening
            let checkIn = CheckIn(
                type: type,
                transcript: userTranscript,
                aiSummary: effectiveIntent.checkInSummary ?? effectiveIntent.reply
            )
            context.insert(checkIn)
            AccountabilityService.recordActivity(in: context)

            if let parsedTasks = effectiveIntent.tasks {
                for parsed in parsedTasks {
                    if let task = allTasks.first(where: { $0.title.localizedCaseInsensitiveContains(parsed.title) || parsed.title.localizedCaseInsensitiveContains($0.title) }) {
                        task.markComplete()
                        NotificationService.cancelTaskReminder(for: task.id)
                        changedTasks.append(task)
                    }
                }
            }

        default:
            break
        }

        do {
            try context.save()
        } catch {
            print("SwiftData save failed: \(error)")
        }

        AccountabilityService.refreshWeekCount(tasks: allTasks, in: context)
        await NotificationService.updateOverdueNudge(tasks: allTasks)
        return changedTasks
    }

    private static func shouldCreateTask(from intent: PAIntent, transcript: String) -> Bool {
        let normalizedIntent = intent.intent.lowercased()
        if normalizedIntent == "create_task" {
            return (intent.tasks ?? []).isEmpty
        }
        let lower = transcript.lowercased()
        let createWords = ["remind", "remember", "add task", "add a task", "schedule", "need to", "have to", "todo", "to do", "don't forget", "dont forget"]
        return createWords.contains(where: { lower.contains($0) }) && (intent.tasks ?? []).isEmpty
    }

    private static func fallbackTasks(from intent: PAIntent, transcript: String) -> [ParsedTask] {
        if let tasks = intent.tasks, !tasks.isEmpty { return tasks }
        let cleaned = transcript
            .replacingOccurrences(of: "^(remind me to|remember to|add task|add a task|schedule|i need to|i have to)\\s*", with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = cleaned.isEmpty ? transcript : cleaned
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dueToday = formatter.string(from: endOfToday())
        return [ParsedTask(title: title.capitalized, dueAt: dueToday)]
    }

    private static func parsePriority(_ raw: String?) -> TaskPriority {
        TaskPriority(rawValue: raw?.lowercased() ?? "") ?? .medium
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let date = isoFormatter.date(from: raw) ?? isoFormatterNoFraction.date(from: raw) {
            return date
        }
        return parseNaturalDate(raw)
    }

    static func endOfToday() -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? Date()
    }

    private static func parseNaturalDate(_ raw: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        return detector?.firstMatch(in: raw, options: [], range: range)?.date
    }

    private static func resolveTask(id: String?, tasks: [TaskItem], hint: String) -> TaskItem? {
        if let id, let uuid = UUID(uuidString: id) {
            return tasks.first { $0.id == uuid }
        }
        let open = tasks.filter { !$0.isCompleted }
        return open.first { task in
            task.title.localizedCaseInsensitiveContains(hint)
                || hint.localizedCaseInsensitiveContains(task.title)
        }
    }
}
