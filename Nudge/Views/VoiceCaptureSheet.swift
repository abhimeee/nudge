import SwiftUI
import SwiftData

struct VoiceCaptureSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]

    let checkInType: CheckInType?

    @State private var speechService = SpeechService(locale: Locale(identifier: "en-US"))
    @State private var isProcessing = false
    @State private var paReply: String?
    @State private var errorMessage: String?
    @State private var createdCount = 0

    private let hints = [
        "Remind me to buy milk tomorrow",
        "Call dentist on 17 May",
        "Cancel buy milk"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                MicButton(isRecording: speechService.isRecording) {
                    Task { await toggleRecording() }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !speechService.transcript.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("You said")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(speechService.transcript)
                                    .font(.body)
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle()
                        }

                        if let paReply {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(AppTheme.accentGradient)
                                Text(paReply)
                                    .font(.body)
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle()
                        }

                        if createdCount > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.success)
                                Text("Created \(createdCount) task\(createdCount == 1 ? "" : "s")")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.success)
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.overdue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardStyle()
                        }

                        if speechService.transcript.isEmpty && !isProcessing {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Try saying")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                ForEach(hints, id: \.self) { hint in
                                    Text("\"\(hint)\"")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }
                    }
                }

                if isProcessing {
                    ProgressView("Saving task…")
                        .tint(AppTheme.accent)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Text(submitButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(AppTheme.divider.opacity(0.4)))
                        .foregroundStyle(canSubmit ? .white : AppTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!canSubmit || isProcessing)
            }
            .padding(AppTheme.spacing)
            .appScreenBackground()
            .navigationTitle(checkInType?.label ?? "Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .task {
                let authorized = await speechService.requestAuthorization()
                if authorized {
                    try? speechService.startRecording()
                } else {
                    errorMessage = "Enable Speech Recognition in Settings → Nudge."
                }
            }
        }
    }

    private var statusText: String {
        if isProcessing { return "Saving your task…" }
        if speechService.isRecording { return "Listening… tap Send when done" }
        if createdCount > 0 { return "Added \(createdCount) task\(createdCount == 1 ? "" : "s"). Speak again or tap Close" }
        return "Speak, then tap Send"
    }

    private var submitButtonTitle: String {
        if isProcessing { return "Saving…" }
        return "Send"
    }

    private var canSubmit: Bool {
        speechService.isRecording || !speechService.currentTranscript().isEmpty
    }

    @MainActor
    private func toggleRecording() async {
        if speechService.isRecording {
            _ = await speechService.stopRecordingAndFinalize()
        } else {
            errorMessage = nil
            do {
                try speechService.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func submit() async {
        guard !isProcessing else { return }

        isProcessing = true
        errorMessage = nil
        paReply = nil

        let text: String
        if speechService.isRecording {
            text = await speechService.stopRecordingAndFinalize()
        } else {
            text = speechService.currentTranscript()
        }

        guard !text.isEmpty else {
            isProcessing = false
            errorMessage = "No speech detected. Tap the mic and try again."
            return
        }

        await processTranscript(text)
        isProcessing = false
    }

    @MainActor
    private func processTranscript(_ text: String) async {
        let intent = IntentProcessor.sttIntent(from: text)
        paReply = intent.reply

        let changed = await IntentProcessor.apply(
            intent,
            userTranscript: text,
            allTasks: allTasks,
            checkInType: checkInType,
            context: modelContext
        )

        switch intent.intent {
        case "cancel_task":
            if changed.isEmpty {
                errorMessage = "Couldn't find that task to cancel."
            } else {
                prepareForNextCapture()
            }
        case "create_task":
            let added = changed.filter { !$0.isCompleted }.count
            if added > 0 {
                createdCount += added
                prepareForNextCapture()
            } else {
                errorMessage = "Couldn't create task. Try rephrasing, e.g. \"Remind me to buy milk tomorrow\"."
            }
        default:
            if changed.isEmpty {
                errorMessage = "I didn't catch that. Try again."
            } else {
                prepareForNextCapture()
            }
        }
    }

    @MainActor
    private func prepareForNextCapture() {
        speechService.clearTranscript()
        do {
            try speechService.startRecording()
        } catch {
            // User can tap mic manually if auto-restart fails.
        }
    }

}
