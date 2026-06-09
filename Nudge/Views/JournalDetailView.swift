import SwiftUI
import SwiftData

struct JournalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: JournalEntry

    @State private var isRefining = false
    @State private var refineError: String?

    private var canRefineWithGemini: Bool {
        AppSettings.shared.hasAPIKey
            && entry.status == .completed
            && (entry.errorMessage != nil || usedPreviewOnly)
    }

    private var usedPreviewOnly: Bool {
        guard let preview = entry.previewTranscript, !preview.isEmpty else { return false }
        return entry.transcript == preview || entry.errorMessage != nil
    }

    private var hasUpcomingPlans: Bool {
        guard let plans = entry.upcomingPlans, !plans.isEmpty else { return false }
        return plans.lowercased() != "none mentioned"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard

                if let summary = entry.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Daily summary", systemImage: "sparkles")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                        Text(summary)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }

                if hasUpcomingPlans, let plans = entry.upcomingPlans {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Upcoming plans", systemImage: "calendar")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                        Text(plans)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }

                if entry.status == .completed, !entry.transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full transcript")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(entry.transcript)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                } else if let preview = entry.previewTranscript, !preview.isEmpty {
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

                if let error = entry.errorMessage ?? refineError {
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

                if entry.status == .completed, !entry.transcript.isEmpty {
                    ShareLink(item: shareText) {
                        Label("Share entry", systemImage: "square.and.arrow.up")
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
        .navigationTitle(entry.recordedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.recordedAt, format: .dateTime.day().month().year().hour().minute())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Label(entry.formattedDuration, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var shareText: String {
        var parts: [String] = []
        if let summary = entry.summary, !summary.isEmpty {
            parts.append("Summary:\n\(summary)")
        }
        if hasUpcomingPlans, let plans = entry.upcomingPlans {
            parts.append("Upcoming plans:\n\(plans)")
        }
        if !entry.transcript.isEmpty {
            parts.append("Transcript:\n\(entry.transcript)")
        }
        return parts.joined(separator: "\n\n")
    }

    @MainActor
    private func refine() async {
        isRefining = true
        refineError = nil
        do {
            try await JournalTranscriptionCoordinator.refineWithGemini(
                entry: entry,
                context: modelContext
            )
        } catch {
            refineError = error.localizedDescription
        }
        isRefining = false
    }
}
