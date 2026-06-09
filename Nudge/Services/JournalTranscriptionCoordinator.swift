import Foundation
import SwiftData

enum JournalTranscriptionCoordinator {
    @MainActor
    static func finishRecording(
        entry: JournalEntry,
        audioURL: URL,
        previewTranscript: String?,
        context: ModelContext
    ) async {
        entry.previewTranscript = previewTranscript?.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.status = .transcribing
        entry.endedAt = Date()
        try? context.save()

        let settings = AppSettings.shared
        let useGemini = settings.useGeminiForConversations && settings.hasAPIKey
        var finalTranscript = ""
        var errorMessage: String?

        if useGemini {
            do {
                finalTranscript = try await GeminiService.shared.transcribeAudio(fileURL: audioURL)
                AudioRecordingService.deleteRecording(at: audioURL)
            } catch {
                errorMessage = error.localizedDescription
                finalTranscript = entry.previewTranscript ?? ""
                AudioRecordingService.deleteRecording(at: audioURL)
            }
        } else {
            finalTranscript = entry.previewTranscript ?? ""
            if finalTranscript.isEmpty {
                errorMessage = settings.hasAPIKey
                    ? "Enable Gemini transcription in Settings for Hinglish accuracy."
                    : "Add a Gemini API key in Settings for transcription."
            }
            AudioRecordingService.deleteRecording(at: audioURL)
        }

        let trimmed = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            entry.status = .failed
            entry.errorMessage = errorMessage ?? "No speech detected."
            entry.transcript = ""
        } else {
            entry.transcript = trimmed
            entry.status = .completed
            entry.errorMessage = errorMessage

            if useGemini, settings.hasAPIKey {
                if let result = try? await GeminiService.shared.summarizeJournalEntry(trimmed) {
                    entry.summary = result.summary
                    entry.upcomingPlans = result.upcomingPlans
                }
            }

            AccountabilityService.recordActivity(in: context)
        }

        try? context.save()
    }

    @MainActor
    static func refineWithGemini(
        entry: JournalEntry,
        context: ModelContext
    ) async throws {
        guard AppSettings.shared.hasAPIKey else {
            throw GeminiError.missingAPIKey
        }

        entry.status = .transcribing
        try? context.save()

        let transcript: String
        if let preview = entry.previewTranscript, !preview.isEmpty, entry.transcript.isEmpty {
            transcript = try await GeminiService.shared.polishTranscript(preview)
        } else if !entry.transcript.isEmpty {
            transcript = try await GeminiService.shared.polishTranscript(entry.transcript)
        } else {
            throw GeminiError.invalidResponse
        }

        entry.transcript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.status = .completed
        entry.errorMessage = nil

        if let result = try? await GeminiService.shared.summarizeJournalEntry(entry.transcript) {
            entry.summary = result.summary
            entry.upcomingPlans = result.upcomingPlans
        }

        try? context.save()
    }
}
