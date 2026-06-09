import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(sort: \JournalEntry.recordedAt, order: .reverse) private var entries: [JournalEntry]
    @State private var showRecordSheet = false
    @State private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !settings.hasAPIKey {
                        apiKeyBanner
                    }

                    JournalListView()
                }
                .padding(AppTheme.spacing)
                .padding(.bottom, 88)
            }
            .appScreenBackground()
            .navigationTitle("Journal")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRecordSheet = true
                    } label: {
                        Label("Record", systemImage: "mic.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .overlay(alignment: .bottom) {
                recordFAB
            }
            .sheet(isPresented: $showRecordSheet) {
                JournalRecordView()
            }
            .navigationDestination(for: UUID.self) { id in
                if let entry = entries.first(where: { $0.id == id }) {
                    JournalDetailView(entry: entry)
                }
            }
        }
    }

    private var apiKeyBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "key.fill")
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Gemini API key")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Required for transcription and daily summaries. Settings → Gemini API.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }

    private var recordFAB: some View {
        Button {
            showRecordSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                Text("Voice journal")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppTheme.accentGradient)
            .clipShape(Capsule())
            .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }
}
