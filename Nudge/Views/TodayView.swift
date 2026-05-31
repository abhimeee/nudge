import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @Query private var statsList: [UserStats]

    @Binding var showVoiceSheet: Bool
    @Binding var checkInType: CheckInType?

    private var stats: UserStats {
        statsList.first ?? UserStats()
    }

    private var overdue: [TaskItem] {
        allTasks.filter { $0.isOverdue }
    }

    private var dueToday: [TaskItem] {
        allTasks.filter { $0.isDueToday }
    }

    private var doneToday: [TaskItem] {
        allTasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }
    }

    private var openAnytime: [TaskItem] {
        allTasks.filter { task in
            !task.isCompleted && !task.isOverdue && !task.isDueToday
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(greeting)
                                .font(.largeTitle.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            StreakBadge(streak: stats.currentStreak)
                        }

                        taskSection(title: "Overdue", tasks: overdue, accent: AppTheme.overdue)
                        taskSection(title: "Due Today", tasks: dueToday, accent: AppTheme.accent)
                        taskSection(title: "Open Tasks", tasks: openAnytime, accent: AppTheme.textPrimary)
                        taskSection(title: "Done Today", tasks: doneToday, accent: AppTheme.success)

                        if overdue.isEmpty && dueToday.isEmpty && openAnytime.isEmpty && doneToday.isEmpty {
                            EmptyStateView(
                                icon: "mic.circle",
                                title: "Nothing here yet",
                                subtitle: "Tap the mic and tell me what you need to do."
                            )
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(AppTheme.spacing)
                }

                MicButton(isRecording: false) {
                    checkInType = nil
                    showVoiceSheet = true
                }
                .padding(.bottom, 24)
            }
            .background(AppTheme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                _ = AccountabilityService.ensureStats(in: modelContext)
                AccountabilityService.resetStreakIfInactive(in: modelContext)
            }
        }
    }

    @ViewBuilder
    private func taskSection(title: String, tasks: [TaskItem], accent: Color) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(accent)

                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        TaskRow(task: task) {
                            toggleTask(task)
                        }
                        if task.id != tasks.last?.id {
                            Divider().overlay(Color.white.opacity(0.08))
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    private func toggleTask(_ task: TaskItem) {
        if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
        } else {
            task.markComplete()
            NotificationService.cancelTaskReminder(for: task.id)
            AccountabilityService.recordActivity(in: modelContext)
        }
        try? modelContext.save()
        AccountabilityService.refreshWeekCount(tasks: allTasks, in: modelContext)
        Task { await NotificationService.updateOverdueNudge(tasks: allTasks) }
    }
}
