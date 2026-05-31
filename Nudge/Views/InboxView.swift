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
                                filter = option
                            } label: {
                                Text(option.rawValue)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(filter == option ? AppTheme.background : AppTheme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(filter == option ? AppTheme.accent : AppTheme.cardBackground)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.spacing)
                }

                if filteredTasks.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "Inbox clear",
                        subtitle: "No open tasks match this filter."
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(filteredTasks) { task in
                            TaskRow(task: task) {
                                toggleTask(task)
                            }
                            .listRowBackground(AppTheme.cardBackground)
                            .listRowSeparatorTint(.white.opacity(0.08))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Inbox")
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
