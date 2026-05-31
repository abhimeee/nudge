import Foundation

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Gemini API key in Settings."
        case .invalidResponse:
            return "Could not parse Gemini response."
        case .apiError(let message):
            return message
        }
    }
}

actor GeminiService {
    static let shared = GeminiService()

    private let models = ["gemini-2.0-flash", "gemini-2.5-flash", "gemini-1.5-flash"]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func processUtterance(_ text: String, context: PAContext) async throws -> PAIntent {
        let apiKey = KeychainHelper.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let apiKey, !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        var lastError: Error = GeminiError.invalidResponse
        for model in models {
            do {
                return try await request(model: model, apiKey: apiKey, text: text, context: context)
            } catch {
                lastError = error
                if case GeminiError.apiError(let message) = error,
                   message.contains("404") || message.contains("not found") {
                    continue
                }
                throw error
            }
        }
        throw lastError
    }

    private func request(model: String, apiKey: String, text: String, context: PAContext) async throws -> PAIntent {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let now = formatter.string(from: Date())
        let timezone = TimeZone.current.identifier

        var checkInHint = ""
        if let checkInType = context.checkInType {
            checkInHint = "The user is responding to a \(checkInType.rawValue) check-in. Mark mentioned tasks complete when appropriate."
        }

        let systemPrompt = """
        You are Nudge, a personal task assistant. Always return JSON matching the schema.

        Current datetime: \(now) (\(timezone))
        Current streak: \(context.currentStreak) days
        \(checkInHint)

        Open tasks:
        \(context.taskSummary)

        Rules:
        - If the user asks to remember, remind, add, or schedule something → intent MUST be "create_task" and include at least one item in "tasks".
        - If the user says they finished something → intent "complete_task".
        - If the user asks what is due/overdue → intent "query_tasks" (tasks can be empty).
        - For create_task, always populate tasks[].title. Parse dueAt/reminderAt as ISO 8601 when a date/time is mentioned.
        - Keep reply under 2 sentences, warm and direct.
        """

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["role": "user", "parts": [["text": text]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": responseSchema
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(message)
        }

        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> PAIntent {
        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]?
                }
                let content: Content?
            }
            let candidates: [Candidate]?
        }

        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = jsonObject["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw GeminiError.apiError(message)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              let jsonData = text.data(using: .utf8) else {
            throw GeminiError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(PAIntent.self, from: jsonData)
        } catch {
            throw GeminiError.apiError("JSON parse failed: \(error.localizedDescription). Raw: \(text.prefix(200))")
        }
    }

    private var responseSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "intent": [
                    "type": "string",
                    "enum": ["create_task", "complete_task", "update_task", "query_tasks", "check_in"]
                ],
                "reply": ["type": "string"],
                "tasks": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string"],
                            "dueAt": ["type": "string", "nullable": true],
                            "priority": ["type": "string", "nullable": true],
                            "reminderAt": ["type": "string", "nullable": true]
                        ],
                        "required": ["title"]
                    ],
                    "nullable": true
                ],
                "taskId": ["type": "string", "nullable": true],
                "checkInSummary": ["type": "string", "nullable": true]
            ],
            "required": ["intent", "reply"]
        ]
    }
}
