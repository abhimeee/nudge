import Foundation
import SwiftData

enum CheckInType: String, Codable, CaseIterable {
    case morning
    case evening

    var label: String {
        switch self {
        case .morning: return "Morning"
        case .evening: return "Evening"
        }
    }
}

@Model
final class CheckIn {
    var id: UUID
    var typeRaw: String
    var date: Date
    var transcript: String
    var aiSummary: String?

    var type: CheckInType {
        get { CheckInType(rawValue: typeRaw) ?? .morning }
        set { typeRaw = newValue.rawValue }
    }

    init(type: CheckInType, transcript: String, aiSummary: String? = nil) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.date = Date()
        self.transcript = transcript
        self.aiSummary = aiSummary
    }
}
