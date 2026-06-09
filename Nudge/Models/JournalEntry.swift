import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var recordedAt: Date
    var endedAt: Date?
    var durationSeconds: Double
    var transcript: String
    var previewTranscript: String?
    var summary: String?
    var upcomingPlans: String?
    var statusRaw: String
    var errorMessage: String?

    var status: ConversationStatus {
        get { ConversationStatus(rawValue: statusRaw) ?? .failed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        recordedAt: Date = Date(),
        transcript: String = "",
        previewTranscript: String? = nil,
        status: ConversationStatus = .recording
    ) {
        self.id = UUID()
        self.recordedAt = recordedAt
        self.endedAt = nil
        self.durationSeconds = 0
        self.transcript = transcript
        self.previewTranscript = previewTranscript
        self.summary = nil
        self.upcomingPlans = nil
        self.statusRaw = status.rawValue
        self.errorMessage = nil
    }

    var displayTitle: String {
        if let summary, !summary.isEmpty {
            return String(summary.prefix(80)) + (summary.count > 80 ? "…" : "")
        }
        let source = transcript.isEmpty ? (previewTranscript ?? "") : transcript
        let line = source
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty { return "Journal entry" }
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
