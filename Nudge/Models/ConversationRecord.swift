import Foundation
import SwiftData

enum ConversationStatus: String, Codable, CaseIterable {
    case recording
    case transcribing
    case completed
    case failed

    var label: String {
        switch self {
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .completed: return "Saved"
        case .failed: return "Failed"
        }
    }
}

@Model
final class ConversationRecord {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Double
    var transcript: String
    var previewTranscript: String?
    var title: String?
    var statusRaw: String
    var errorMessage: String?

    var status: ConversationStatus {
        get { ConversationStatus(rawValue: statusRaw) ?? .failed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        startedAt: Date = Date(),
        transcript: String = "",
        previewTranscript: String? = nil,
        status: ConversationStatus = .recording
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = nil
        self.durationSeconds = 0
        self.transcript = transcript
        self.previewTranscript = previewTranscript
        self.title = nil
        self.statusRaw = status.rawValue
        self.errorMessage = nil
    }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        let source = transcript.isEmpty ? (previewTranscript ?? "") : transcript
        let line = source
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty { return "Conversation" }
        return String(line.prefix(80)) + (line.count > 80 ? "…" : "")
    }

    var formattedDuration: String {
        let total = Int(durationSeconds.rounded())
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}
