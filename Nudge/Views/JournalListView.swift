import SwiftUI
import SwiftData

struct JournalListView: View {
    @Query(sort: \JournalEntry.recordedAt, order: .reverse) private var entries: [JournalEntry]

    var body: some View {
        Group {
            if entries.isEmpty {
                EmptyStateView(
                    icon: "book.closed.fill",
                    title: "No journal entries yet",
                    subtitle: "Record your thoughts, reflections, and plans for the days ahead. Gemini creates a daily summary for you."
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        NavigationLink(value: entry.id) {
                            journalRow(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func journalRow(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.recordedAt, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                statusBadge(entry)
            }

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(entry.formattedDuration)
                    .font(.caption)
            }
            .foregroundStyle(AppTheme.textSecondary)

            if let summary = entry.summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } else {
                Text(entry.displayTitle)
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            if let plans = entry.upcomingPlans,
               !plans.isEmpty,
               plans.lowercased() != "none mentioned" {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("Plans noted")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }

    @ViewBuilder
    private func statusBadge(_ entry: JournalEntry) -> some View {
        let (text, color): (String, Color) = {
            switch entry.status {
            case .recording: return ("Recording", AppTheme.sky)
            case .transcribing: return ("Processing…", AppTheme.peach)
            case .completed: return ("Saved", AppTheme.success)
            case .failed: return ("Failed", AppTheme.overdue)
            }
        }()
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
