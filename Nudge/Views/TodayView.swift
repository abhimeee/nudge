import SwiftUI
import SwiftData

private enum TodaySection: String, CaseIterable {
    case overdue = "Needs attention"
    case dueToday = "Due today"
    case open = "Up next"
    case done = "Wins today"

    var icon: String {
        switch self {
        case .overdue: return "bell.badge.fill"
        case .dueToday: return "sun.horizon.fill"
        case .open: return "sparkles"
        case .done: return "party.popper.fill"
        }
    }
}

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @Query private var statsList: [UserStats]

    @Binding var showVoiceSheet: Bool
    @Binding var checkInType: CheckInType?

    @State private var heroVisible = false

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

    private var hasAnyTasks: Bool {
        !overdue.isEmpty || !dueToday.isEmpty || !openAnytime.isEmpty || !doneToday.isEmpty
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        heroHeader

                        sectionBlock(.overdue, tasks: overdue, color: AppTheme.overdue, startIndex: 0)
                        sectionBlock(.dueToday, tasks: dueToday, color: AppTheme.accent, startIndex: 1)
                        sectionBlock(.open, tasks: openAnytime, color: AppTheme.sky, startIndex: 2)
                        sectionBlock(.done, tasks: doneToday, color: AppTheme.success, startIndex: 3)

                        if !hasAnyTasks {
                            EmptyStateView(
                                icon: "waveform.circle.fill",
                                title: "Your canvas is clear",
                                subtitle: "Hold the mic and tell me what you're tackling. I'll sort it into your day."
                            )
                            .staggeredAppear(index: 4)
                        }

                        Spacer(minLength: 110)
                    }
                    .padding(.horizontal, AppTheme.spacing)
                    .padding(.top, 8)
                }

                MicButton(isRecording: false) {
                    checkInType = nil
                    showVoiceSheet = true
                }
                .padding(.bottom, 28)
            }
            .appScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                _ = AccountabilityService.ensureStats(in: modelContext)
                AccountabilityService.resetStreakIfInactive(in: modelContext)
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    heroVisible = true
                }
            }
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(dateLine.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.textSecondary)

            Text(greeting)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.heroGradient)

            StreakBadge(streak: stats.currentStreak)
        }
        .opacity(heroVisible ? 1 : 0)
        .offset(y: heroVisible ? 0 : 20)
    }

    @ViewBuilder
    private func sectionBlock(
        _ section: TodaySection,
        tasks: [TaskItem],
        color: Color,
        startIndex: Int
    ) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: section.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text(section.rawValue)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()
                }

                VStack(spacing: 10) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        TaskRow(task: task, style: .card, accent: color) {
                            toggleTask(task)
                        }
                        .staggeredAppear(index: startIndex * 3 + index + 1)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: tasks.map(\.id))
        }
    }

    private func toggleTask(_ task: TaskItem) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            if task.isCompleted {
                task.isCompleted = false
                task.completedAt = nil
            } else {
                task.markComplete()
                NotificationService.cancelTaskReminder(for: task.id)
                AccountabilityService.recordActivity(in: modelContext)
            }
        }
        try? modelContext.save()
        AccountabilityService.refreshWeekCount(tasks: allTasks, in: modelContext)
        Task { await NotificationService.updateOverdueNudge(tasks: allTasks) }
    }
}
