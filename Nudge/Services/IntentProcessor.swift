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
        if let cancelIntent = parseCancelIntent(from: transcript) {
            return cancelIntent
        }

        let parsed = parseSTTTask(from: transcript)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return PAIntent(
            intent: "create_task",
            reply: parsed.reply,
            tasks: [ParsedTask(title: parsed.title, dueAt: formatter.string(from: parsed.dueDate))]
        )
    }

    private static func parseSTTTask(from transcript: String) -> (title: String, dueDate: Date, reply: String) {
        let (dueDate, remainder) = extractDueDate(from: transcript)
        let title = cleanedTitle(from: remainder.isEmpty ? transcript : remainder)
        return (title, dueDate, replyForDueDate(dueDate))
    }

    private static func parseCancelIntent(from transcript: String) -> PAIntent? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        let cancelWords = ["cancel", "remove", "delete", "drop", "scratch", "never mind", "nevermind", "forget about"]
        guard cancelWords.contains(where: { lower.contains($0) }) else { return nil }

        let hint = cancelHint(from: trimmed)
        guard !hint.isEmpty else { return nil }

        return PAIntent(
            intent: "cancel_task",
            reply: "Removed.",
            tasks: [ParsedTask(title: hint)]
        )
    }

    private static func cancelHint(from text: String) -> String {
        var hint = text
        let patterns = [
            "^(please\\s+)?(cancel|remove|delete|drop|scratch)\\s+(the\\s+)?(task\\s+)?(to\\s+)?",
            "^(please\\s+)?(never mind|nevermind|forget about)\\s+(the\\s+)?(task\\s+)?(to\\s+)?"
        ]
        for pattern in patterns {
            hint = hint.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return hint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractDueDate(from transcript: String) -> (date: Date, remainder: String) {
        let calendar = Calendar.current
        var text = transcript

        let relativePatterns: [(pattern: String, dayOffset: Int)] = [
            ("day after tomorrow", 2),
            ("tomorrow", 1),
            ("tonight", 0),
            ("today", 0)
        ]

        for (pattern, dayOffset) in relativePatterns {
            if text.range(of: pattern, options: [.caseInsensitive]) != nil {
                let base = calendar.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
                text = removeDatePhrase(pattern, from: text)
                return (endOfDay(for: base), normalizeRemainder(text))
            }
        }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = detector.firstMatch(in: text, options: [], range: nsRange),
               let date = match.date,
               let range = Range(match.range, in: text) {
                text.removeSubrange(range)
                return (endOfDay(for: date), normalizeRemainder(text))
            }
        }

        return (endOfToday(), transcript)
    }

    private static func removeDatePhrase(_ pattern: String, from text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
        guard let regex = try? NSRegularExpression(
            pattern: "(?:\\b(?:on|for|by|this|next)\\s+)?\(escaped)\\b",
            options: [.caseInsensitive]
        ) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    private static func normalizeRemainder(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\b(on|for|by|this|next)\\s*$", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "^\\s*(on|for|by|this|next)\\s+", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",.")))
    }

    private static func replyForDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Added to today." }
        if calendar.isDateInTomorrow(date) { return "Added for tomorrow." }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Added for \(formatter.string(from: date))."
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

        case "cancel_task":
            let hint = effectiveIntent.tasks?.first?.title ?? cancelHint(from: userTranscript)
            if let task = resolveTask(id: effectiveIntent.taskId, tasks: allTasks, hint: hint) {
                NotificationService.cancelTaskReminder(for: task.id)
                context.delete(task)
                changedTasks.append(task)
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
        let parsed = parseSTTTask(from: transcript)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return [ParsedTask(title: parsed.title, dueAt: formatter.string(from: parsed.dueDate))]
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
        endOfDay(for: Date())
    }

    static func endOfDay(for date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
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
