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
                        statCard(title: "Current", value: "\(stats.currentStreak)", subtitle: "day streak", tint: AppTheme.accent)
                            .staggeredAppear(index: 0)
                        statCard(title: "Best", value: "\(stats.longestStreak)", subtitle: "day streak", tint: AppTheme.accentSecondary)
                            .staggeredAppear(index: 1)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("This week")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(stats.weekCompletedCount) tasks completed")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.heroGradient)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .staggeredAppear(index: 2)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Last 7 days")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        HStack(spacing: 10) {
                            ForEach(Array(activityDots.enumerated()), id: \.offset) { index, active in
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            active
                                                ? AnyShapeStyle(AppTheme.accentGradient)
                                                : AnyShapeStyle(AppTheme.divider.opacity(0.5))
                                        )
                                        .frame(height: 36)
                                        .overlay {
                                            if active {
                                                Image(systemName: "checkmark")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .scaleEffect(active ? 1 : 0.92)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.04), value: active)

                                    Text(dayLabel(offset: 6 - index))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .cardStyle()
                    .staggeredAppear(index: 3)
                }
                .padding(AppTheme.spacing)
            }
            .appScreenBackground()
            .navigationTitle("Stats")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                AccountabilityService.refreshWeekCount(tasks: allTasks, in: modelContext)
            }
        }
    }

    private func statCard(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
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
