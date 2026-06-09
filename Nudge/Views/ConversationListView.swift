import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Query(sort: \ConversationRecord.startedAt, order: .reverse) private var conversations: [ConversationRecord]

    var body: some View {
        Group {
            if conversations.isEmpty {
                EmptyStateView(
                    icon: "waveform.circle",
                    title: "No conversations yet",
                    subtitle: "Tap Record to log an in-person chat. Transcripts work best with Gemini for Hinglish."
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(conversations) { record in
                        NavigationLink(value: record.id) {
                            conversationRow(record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func conversationRow(_ record: ConversationRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.startedAt, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                statusBadge(record)
            }

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(record.formattedDuration)
                    .font(.caption)
            }
            .foregroundStyle(AppTheme.textSecondary)

            Text(record.displayTitle)
                .font(.body)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }

    @ViewBuilder
    private func statusBadge(_ record: ConversationRecord) -> some View {
        let (text, color): (String, Color) = {
            switch record.status {
            case .recording: return ("Recording", AppTheme.sky)
            case .transcribing: return ("Transcribing…", AppTheme.peach)
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
