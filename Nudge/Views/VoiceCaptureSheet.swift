import SwiftUI
import SwiftData

struct VoiceCaptureSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @Query private var statsList: [UserStats]

    let checkInType: CheckInType?

    @State private var speechService = SpeechService()
    @State private var isProcessing = false
    @State private var paReply: String?
    @State private var errorMessage: String?
    @State private var createdCount = 0
    @State private var hasProcessed = false
    @State private var lastProcessedText = ""

    private let hints = [
        "Remind me to call dentist Tuesday at 2pm",
        "What's overdue?",
        "I finished the gym task"
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
                                    .font(.caption)
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
                                    .foregroundStyle(AppTheme.accent)
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
                                    .font(.caption)
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
                    ProgressView("Sending to Nudge…")
                        .tint(AppTheme.accent)
                }

                Button {
                    Task { await submit(dismissAfter: true) }
                } label: {
                    Text(submitButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? AppTheme.accent : AppTheme.cardBackground)
                        .foregroundStyle(canSubmit ? AppTheme.background : AppTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSubmit || isProcessing)
            }
            .padding(AppTheme.spacing)
            .background(AppTheme.background)
            .navigationTitle(checkInType?.label ?? "Voice")
            .navigationBarTitleDisplayMode(.inline)
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
        if isProcessing { return "Processing your request…" }
        if speechService.isRecording { return "Listening… tap Send when done" }
        if hasProcessed { return "Done! Check Today or Inbox" }
        return "Speak, then tap Send"
    }

    private var submitButtonTitle: String {
        if isProcessing { return "Processing…" }
        if speechService.isRecording { return "Send" }
        if hasProcessed { return "Send again" }
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
            hasProcessed = false
            do {
                try speechService.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func submit(dismissAfter: Bool) async {
        guard !isProcessing else { return }

        isProcessing = true
        errorMessage = nil

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

        if text == lastProcessedText, hasProcessed {
            isProcessing = false
            if dismissAfter { dismiss() }
            return
        }

        await processTranscript(text)
        isProcessing = false

        if dismissAfter, errorMessage == nil {
            try? await Task.sleep(nanoseconds: 800_000_000)
            dismiss()
        }
    }

    @MainActor
    private func processTranscript(_ text: String) async {
        let stats = statsList.first ?? AccountabilityService.ensureStats(in: modelContext)
        let openTasks = allTasks.filter { !$0.isCompleted }.prefix(20).map {
            (id: $0.id, title: $0.title, dueDate: $0.dueDate, priority: $0.priority)
        }

        let context = PAContext(
            openTasks: Array(openTasks),
            currentStreak: stats.currentStreak,
            checkInType: checkInType
        )

        let apiKey = KeychainHelper.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let intent: PAIntent
            if let apiKey, !apiKey.isEmpty {
                intent = try await GeminiService.shared.processUtterance(text, context: context)
            } else {
                intent = localFallbackIntent(for: text)
                errorMessage = "No API key — saved task locally. Add Gemini key in Settings for smarter parsing."
            }

            paReply = intent.reply
            let changed = await IntentProcessor.apply(
                intent,
                userTranscript: text,
                allTasks: allTasks,
                checkInType: checkInType,
                context: modelContext
            )
            createdCount = changed.filter { !$0.isCompleted }.count
            hasProcessed = true
            lastProcessedText = text

            if createdCount == 0, intent.intent == "create_task" {
                errorMessage = "Couldn't create task. Try rephrasing, e.g. \"Remind me to buy milk tomorrow\"."
            }
        } catch {
            let fallback = localFallbackIntent(for: text)
            paReply = fallback.reply
            let changed = await IntentProcessor.apply(
                fallback,
                userTranscript: text,
                allTasks: allTasks,
                checkInType: checkInType,
                context: modelContext
            )
            createdCount = changed.filter { !$0.isCompleted }.count
            hasProcessed = true
            lastProcessedText = text

            if createdCount > 0 {
                errorMessage = "Gemini unavailable — created task locally. (\(error.localizedDescription))"
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func localFallbackIntent(for text: String) -> PAIntent {
        PAIntent(
            intent: "create_task",
            reply: "Got it — I'll track that for you.",
            tasks: [ParsedTask(title: cleanedTitle(from: text))]
        )
    }

    private func cleanedTitle(from text: String) -> String {
        let cleaned = text
            .replacingOccurrences(
                of: "^(remind me to|remember to|add task|add a task|schedule|i need to|i have to)\\s*",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = cleaned.isEmpty ? text : cleaned
        return title.prefix(1).uppercased() + title.dropFirst()
    }
}
