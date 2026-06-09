import Foundation
import SwiftData

enum ConversationTranscriptionCoordinator {
    @MainActor
    static func finishRecording(
        record: ConversationRecord,
        audioURL: URL,
        previewTranscript: String?,
        context: ModelContext
    ) async {
        record.previewTranscript = previewTranscript?.trimmingCharacters(in: .whitespacesAndNewlines)
        record.status = .transcribing
        record.endedAt = Date()
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
                finalTranscript = record.previewTranscript ?? ""
                AudioRecordingService.deleteRecording(at: audioURL)
            }
        } else {
            finalTranscript = record.previewTranscript ?? ""
            if finalTranscript.isEmpty {
                errorMessage = settings.hasAPIKey
                    ? "Enable Gemini transcription in Settings for Hinglish accuracy."
                    : "Add a Gemini API key in Settings for transcription."
            }
            AudioRecordingService.deleteRecording(at: audioURL)
        }

        let trimmed = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            record.status = .failed
            record.errorMessage = errorMessage ?? "No speech detected."
            record.transcript = ""
        } else {
            record.transcript = trimmed
            record.status = .completed
            record.errorMessage = errorMessage

            if useGemini, settings.hasAPIKey {
                if let title = try? await GeminiService.shared.summarizeTranscript(trimmed) {
                    record.title = title
                }
            }
        }

        try? context.save()
    }

    @MainActor
    static func refineWithGemini(
        record: ConversationRecord,
        audioURL: URL?,
        context: ModelContext
    ) async throws {
        guard AppSettings.shared.hasAPIKey else {
            throw GeminiError.missingAPIKey
        }

        record.status = .transcribing
        try? context.save()

        let transcript: String
        if let audioURL, FileManager.default.fileExists(atPath: audioURL.path) {
            transcript = try await GeminiService.shared.transcribeAudio(fileURL: audioURL)
            AudioRecordingService.deleteRecording(at: audioURL)
        } else if let preview = record.previewTranscript, !preview.isEmpty {
            transcript = try await GeminiService.shared.polishTranscript(preview)
        } else if !record.transcript.isEmpty {
            transcript = try await GeminiService.shared.polishTranscript(record.transcript)
        } else {
            throw GeminiError.invalidResponse
        }

        record.transcript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        record.status = .completed
        record.errorMessage = nil
        if let title = try? await GeminiService.shared.summarizeTranscript(record.transcript) {
            record.title = title
        }
        try? context.save()
    }
}
