import SwiftUI
import SwiftData

enum InboxFilter: String, CaseIterable {
    case all = "All"
    case high = "High"
    case noDate = "No date"
}

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate, order: .forward) private var allTasks: [TaskItem]
    @State private var filter: InboxFilter = .all

    private var openTasks: [TaskItem] {
        allTasks.filter { !$0.isCompleted }
    }

    private var filteredTasks: [TaskItem] {
        switch filter {
        case .all:
            return openTasks
        case .high:
            return openTasks.filter { $0.priority == .high }
        case .noDate:
            return openTasks.filter { $0.dueDate == nil }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(InboxFilter.allCases, id: \.self) { option in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                    filter = option
                                }
                            } label: {
                                Text(option.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(filter == option ? .white : AppTheme.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .background {
                                        if filter == option {
                                            Capsule().fill(AppTheme.accentGradient)
                                        } else {
                                            Capsule().fill(AppTheme.cardBackground)
                                                .shadow(color: AppTheme.cardShadow, radius: 6, y: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.spacing)
                }

                if filteredTasks.isEmpty {
                    EmptyStateView(
                        icon: "tray.fill",
                        title: "Inbox is zen",
                        subtitle: "No open tasks match this filter. Nice work."
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(filteredTasks.enumerated()), id: \.element.id) { index, task in
                                TaskRow(task: task, style: .card, onToggle: {
                                    toggleTask(task)
                                }, onCancel: {
                                    cancelTask(task)
                                })
                                .staggeredAppear(index: index)
                            }
                        }
                        .padding(.horizontal, AppTheme.spacing)
                        .padding(.bottom, 24)
                    }
                }
            }
            .appScreenBackground()
            .navigationTitle("Inbox")
            .toolbarBackground(.hidden, for: .navigationBar)
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

    private func cancelTask(_ task: TaskItem) {
        Task { @MainActor in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                NotificationService.cancelTaskReminder(for: task.id)
                modelContext.delete(task)
                try? modelContext.save()
            }
            AccountabilityService.refreshWeekCount(tasks: allTasks, in: modelContext)
            await NotificationService.updateOverdueNudge(tasks: allTasks)
        }
    }
}
