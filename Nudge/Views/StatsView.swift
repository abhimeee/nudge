import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var statsList: [UserStats]
    @Query(sort: \TaskItem.completedAt, order: .reverse) private var allTasks: [TaskItem]
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]

    private var stats: UserStats {
        statsList.first ?? UserStats()
    }

    private var activityDots: [Bool] {
        AccountabilityService.activityForLastSevenDays(tasks: allTasks, checkIns: checkIns)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        statCard(title: "Current", value: "\(stats.currentStreak)", subtitle: "day streak")
                        statCard(title: "Best", value: "\(stats.longestStreak)", subtitle: "day streak")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("This week")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(stats.weekCompletedCount) tasks completed")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Last 7 days")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        HStack(spacing: 12) {
                            ForEach(Array(activityDots.enumerated()), id: \.offset) { index, active in
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(active ? AppTheme.accent : AppTheme.cardBackground)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                    Text(dayLabel(offset: 6 - index))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .cardStyle()
                }
                .padding(AppTheme.spacing)
            }
            .background(AppTheme.background)
            .navigationTitle("Stats")
            .onAppear {
                AccountabilityService.refreshWeekCount(tasks: allTasks, in: modelContext)
            }
        }
    }

    private func statCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func dayLabel(offset: Int) -> String {
        guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
