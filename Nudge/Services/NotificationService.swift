import Foundation
import UserNotifications

enum NotificationService {
    static let morningCheckInID = "nudge.morning.checkin"
    static let eveningCheckInID = "nudge.evening.checkin"
    static let overdueNudgeID = "nudge.overdue.nudge"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleTaskReminder(for task: TaskItem) async {
        let fireDate = task.reminderDate ?? task.dueDate
        guard let fireDate, fireDate > Date(), !task.isCompleted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = task.title
        content.sound = .default
        content.userInfo = ["taskId": task.id.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: taskNotificationID(task.id),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelTaskReminder(for taskID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [taskNotificationID(taskID)])
    }

    static func rescheduleDailyNotifications() async {
        let settings = AppSettings.shared
        await scheduleDaily(
            id: morningCheckInID,
            title: "Good morning",
            body: "What's your plan for today? Open Nudge to tell me.",
            components: settings.morningCheckInTime
        )
        await scheduleDaily(
            id: eveningCheckInID,
            title: "Evening review",
            body: "How did today go? Tell me what you finished.",
            components: settings.eveningCheckInTime
        )
        await scheduleDaily(
            id: overdueNudgeID,
            title: "Overdue tasks",
            body: "You have tasks waiting. Open Nudge to catch up.",
            components: settings.overdueNudgeTime
        )
    }

    static func updateOverdueNudge(tasks: [TaskItem]) async {
        let overdue = tasks.filter { $0.isOverdue }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [overdueNudgeID])

        guard !overdue.isEmpty else { return }

        let titles = overdue.prefix(3).map(\.title).joined(separator: ", ")
        let suffix = overdue.count > 3 ? " and \(overdue.count - 3) more" : ""

        let content = UNMutableNotificationContent()
        content.title = "Still overdue"
        content.body = "You still have \(overdue.count) task(s): \(titles)\(suffix)"
        content.sound = .default
        content.userInfo = ["openVoice": true]

        let components = AppSettings.shared.overdueNudgeTime
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: overdueNudgeID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private static func scheduleDaily(
        id: String,
        title: String,
        body: String,
        components: DateComponents
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["checkIn": id == morningCheckInID ? "morning" : "evening"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private static func taskNotificationID(_ id: UUID) -> String {
        "nudge.task.\(id.uuidString)"
    }
}
