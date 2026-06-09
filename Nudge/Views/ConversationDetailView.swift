import SwiftUI
import SwiftData

struct ConversationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var record: ConversationRecord

    @State private var isRefining = false
    @State private var refineError: String?

    private var canRefineWithGemini: Bool {
        AppSettings.shared.hasAPIKey
            && record.status == .completed
            && (record.errorMessage != nil || usedPreviewOnly)
    }

    private var usedPreviewOnly: Bool {
        guard let preview = record.previewTranscript, !preview.isEmpty else { return false }
        return record.transcript == preview || record.errorMessage != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard

                if record.status == .completed, !record.transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcript")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(record.transcript)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                } else if let preview = record.previewTranscript, !preview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview transcript")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(preview)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }

                if let error = record.errorMessage ?? refineError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.overdue)
                        .cardStyle()
                }

                if canRefineWithGemini {
                    Button {
                        Task { await refine() }
                    } label: {
                        HStack {
                            if isRefining {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isRefining ? "Refining…" : "Refine with Gemini")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.accentGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefining)
                }

                if record.status == .completed, !record.transcript.isEmpty {
                    ShareLink(item: record.transcript) {
                        Label("Share transcript", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(AppTheme.accent)
                            .background(AppTheme.accentMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(AppTheme.spacing)
            .padding(.bottom, 24)
        }
        .appScreenBackground()
        .navigationTitle(record.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.startedAt, format: .dateTime.day().month().year().hour().minute())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 12) {
                Label(record.formattedDuration, systemImage: "clock")
                if let title = record.title, !title.isEmpty {
                    Label(title, systemImage: "text.quote")
                }
            }
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @MainActor
    private func refine() async {
        isRefining = true
        refineError = nil
        do {
            try await ConversationTranscriptionCoordinator.refineWithGemini(
                record: record,
                audioURL: nil,
                context: modelContext
            )
        } catch {
            refineError = error.localizedDescription
        }
        isRefining = false
    }
}
