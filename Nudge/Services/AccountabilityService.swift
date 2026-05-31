import Foundation
import SwiftData

enum AccountabilityService {
    static func ensureStats(in context: ModelContext) -> UserStats {
        let descriptor = FetchDescriptor<UserStats>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let stats = UserStats()
        context.insert(stats)
        try? context.save()
        return stats
    }

    static func recordActivity(on date: Date = Date(), in context: ModelContext) {
        let stats = ensureStats(in: context)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        if let last = stats.lastActiveDate {
            let lastDay = calendar.startOfDay(for: last)
            let dayDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if dayDiff == 0 {
                return
            } else if dayDiff == 1 {
                stats.currentStreak += 1
            } else {
                stats.currentStreak = 1
            }
        } else {
            stats.currentStreak = 1
        }

        stats.lastActiveDate = today
        stats.longestStreak = max(stats.longestStreak, stats.currentStreak)
        try? context.save()
    }

    static func refreshWeekCount(tasks: [TaskItem], in context: ModelContext) {
        let stats = ensureStats(in: context)
        let calendar = Calendar.current
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else { return }

        stats.weekCompletedCount = tasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= weekStart
        }.count
        try? context.save()
    }

    static func activityForLastSevenDays(tasks: [TaskItem], checkIns: [CheckIn]) -> [Bool] {
        let calendar = Calendar.current
        return (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return false }
            let start = calendar.startOfDay(for: day)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }

            let completedTask = tasks.contains { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= start && completedAt < end
            }
            let hadCheckIn = checkIns.contains { $0.date >= start && $0.date < end }
            return completedTask || hadCheckIn
        }
    }

    static func resetStreakIfInactive(in context: ModelContext) {
        let stats = ensureStats(in: context)
        guard let last = stats.lastActiveDate else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: last)
        let dayDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if dayDiff > 1 {
            stats.currentStreak = 0
            try? context.save()
        }
    }
}
