import SwiftUI
import SwiftData

struct JournalRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var audioService = AudioRecordingService()
    @State private var speechService = SpeechService(locale: Locale(identifier: "en-IN"))
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                if audioService.isRecording || isProcessing {
                    Text(formattedElapsed)
                        .font(.system(.title2, design: .rounded).weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary)
                }

                MicButton(isRecording: audioService.isRecording) {
                    Task { await toggleRecording() }
                }
                .disabled(isProcessing)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !speechService.transcript.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Live preview (approximate)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(speechService.transcript)
                                    .font(.body)
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle()
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.overdue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardStyle()
                        }

                        if !audioService.isRecording && speechService.transcript.isEmpty && !isProcessing {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What's on your mind?")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Share your thoughts, how your day went, and plans for the coming days. Gemini will create a summary when you save.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle()
                        }
                    }
                }

                if isProcessing {
                    ProgressView("Creating your journal entry…")
                        .tint(AppTheme.accent)
                }

                Button {
                    Task { await stopAndSave() }
                } label: {
                    Text(stopButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canStop ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(AppTheme.divider.opacity(0.4)))
                        .foregroundStyle(canStop ? .white : AppTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!canStop || isProcessing)
            }
            .padding(AppTheme.spacing)
            .appScreenBackground()
            .navigationTitle("Voice journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if audioService.isRecording {
                            audioService.cancelRecording()
                        }
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    .disabled(isProcessing)
                }
            }
            .task {
                let micOK = await audioService.requestPermission()
                guard micOK else {
                    errorMessage = "Enable microphone access in Settings → Nudge."
                    return
                }
                let speechOK = await speechService.requestAuthorization()
                if !speechOK {
                    errorMessage = "Enable Speech Recognition for live preview in Settings → Nudge."
                }
            }
            .onDisappear {
                if audioService.isRecording {
                    audioService.cancelRecording()
                }
            }
        }
    }

    private var statusText: String {
        if isProcessing { return "Saving and summarizing…" }
        if audioService.isRecording { return "Recording… tap Stop & save when done" }
        return "Tap the mic to start"
    }

    private var stopButtonTitle: String {
        if isProcessing { return "Saving…" }
        return "Stop & save"
    }

    private var canStop: Bool {
        audioService.isRecording
    }

    private var formattedElapsed: String {
        let total = Int(audioService.elapsedSeconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    @MainActor
    private func toggleRecording() async {
        if audioService.isRecording { return }
        errorMessage = nil
        do {
            _ = try audioService.startRecording()
            if speechService.authorizationStatus == .authorized {
                try? speechService.startRecording()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func stopAndSave() async {
        guard audioService.isRecording, !isProcessing else { return }

        isProcessing = true
        errorMessage = nil

        let preview: String
        if speechService.isRecording {
            preview = await speechService.stopRecordingAndFinalize()
        } else {
            preview = speechService.currentTranscript()
        }

        do {
            let recordedAt = audioService.recordingStartedAt ?? Date()
            let result = try audioService.stopRecording()
            let entry = JournalEntry(recordedAt: recordedAt)
            entry.durationSeconds = result.duration
            entry.previewTranscript = preview.isEmpty ? nil : preview
            modelContext.insert(entry)
            try? modelContext.save()

            await JournalTranscriptionCoordinator.finishRecording(
                entry: entry,
                audioURL: result.url,
                previewTranscript: preview.isEmpty ? nil : preview,
                context: modelContext
            )

            if entry.status == .failed {
                errorMessage = entry.errorMessage
                isProcessing = false
            } else {
                dismiss()
            }
        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
        }
    }
}
