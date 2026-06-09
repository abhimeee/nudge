import Foundation

struct JournalSummary: Decodable {
    let summary: String
    let upcomingPlans: String?
}

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

    private static let inlineAudioMaxBytes = 18_000_000
    private static let transcriptionPrompt = """
    Transcribe this audio verbatim. The speaker may use Hinglish (Hindi and English mixed).
    Preserve Roman Hindi and Devanagari as spoken. Do not translate.
    Return only the transcript text, no preamble or markdown.
    """

    func transcribeAudio(fileURL: URL) async throws -> String {
        let apiKey = KeychainHelper.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let apiKey, !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let audioData = try Data(contentsOf: fileURL)
        var lastError: Error = GeminiError.invalidResponse

        for model in models {
            do {
                if audioData.count <= Self.inlineAudioMaxBytes {
                    return try await transcribeInline(
                        model: model,
                        apiKey: apiKey,
                        audioData: audioData,
                        mimeType: "audio/mp4"
                    )
                }
                return try await transcribeViaFileAPI(
                    model: model,
                    apiKey: apiKey,
                    fileURL: fileURL,
                    mimeType: "audio/mp4"
                )
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

    /// Improves an Apple Speech preview transcript when original audio is unavailable.
    func polishTranscript(_ roughTranscript: String) async throws -> String {
        let prompt = """
        Clean up this rough speech-to-text transcript. The speaker used Hinglish (Hindi–English mix).
        Fix obvious errors but keep the same language mix and meaning. Return only the cleaned transcript.
        Rough transcript:
        \(roughTranscript)
        """
        let apiKey = KeychainHelper.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let apiKey, !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        var lastError: Error = GeminiError.invalidResponse
        for model in models {
            do {
                return try await generatePlainText(model: model, apiKey: apiKey, prompt: prompt)
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

    func summarizeTranscript(_ transcript: String) async throws -> String {
        let apiKey = KeychainHelper.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let apiKey, !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let prompt = """
        Given this conversation transcript, reply with ONE short title (max 8 words). No quotes.
        Transcript:
        \(transcript.prefix(4000))
        """

        var lastError: Error = GeminiError.invalidResponse
        for model in models {
            do {
                let text = try await generatePlainText(model: model, apiKey: apiKey, prompt: prompt)
                let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { return title }
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

    func summarizeJournalEntry(_ transcript: String) async throws -> JournalSummary {
        let apiKey = KeychainHelper.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let apiKey, !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let prompt = """
        Given this voice journal transcript, return JSON with:
        - "summary": 2-4 sentences capturing the speaker's thoughts, reflections, and how their day went. Warm and personal tone.
        - "upcomingPlans": bullet points (as a single string with newlines) of plans mentioned for upcoming days. Use "None mentioned" if none.

        Transcript:
        \(transcript.prefix(6000))
        """

        var lastError: Error = GeminiError.invalidResponse
        for model in models {
            do {
                let text = try await generateJSON(model: model, apiKey: apiKey, prompt: prompt, schema: journalSummarySchema)
                guard let data = text.data(using: .utf8),
                      let result = try? JSONDecoder().decode(JournalSummary.self, from: data) else {
                    throw GeminiError.invalidResponse
                }
                return result
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

    private func transcribeInline(model: String, apiKey: String, audioData: Data, mimeType: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": Self.transcriptionPrompt],
                        [
                            "inlineData": [
                                "mimeType": mimeType,
                                "data": audioData.base64EncodedString()
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(message)
        }
        return try parsePlainTextResponse(data)
    }

    private func transcribeViaFileAPI(model: String, apiKey: String, fileURL: URL, mimeType: String) async throws -> String {
        let fileURI = try await uploadAudioFile(apiKey: apiKey, fileURL: fileURL, mimeType: mimeType)
        defer { Task { await deleteUploadedFile(apiKey: apiKey, fileURI: fileURI) } }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": Self.transcriptionPrompt],
                        [
                            "fileData": [
                                "mimeType": mimeType,
                                "fileUri": fileURI
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(message)
        }
        return try parsePlainTextResponse(data)
    }

    private func uploadAudioFile(apiKey: String, fileURL: URL, mimeType: String) async throws -> String {
        let uploadURL = URL(string: "https://generativelanguage.googleapis.com/upload/v1beta/files?key=\(apiKey)")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 300

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let metadata: [String: Any] = ["file": ["displayName": fileURL.lastPathComponent]]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(message)
        }

        struct UploadResponse: Decodable {
            struct FileInfo: Decodable {
                let name: String?
                let uri: String?
                let state: String?
            }
            let file: FileInfo?
        }

        let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
        guard let uri = decoded.file?.uri else {
            throw GeminiError.invalidResponse
        }

        if let name = decoded.file?.name, decoded.file?.state != "ACTIVE" {
            try await waitForFileActive(apiKey: apiKey, fileName: name)
        }
        return uri
    }

    private func waitForFileActive(apiKey: String, fileName: String) async throws {
        let name = fileName.hasPrefix("files/") ? fileName : "files/\(fileName)"
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/\(name)?key=\(apiKey)")!

        for _ in 0..<60 {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 30
            let (data, _) = try await session.data(for: request)

            struct FileStatus: Decodable {
                let state: String?
            }

            if let decoded = try? JSONDecoder().decode(FileStatus.self, from: data),
               decoded.state == "ACTIVE" {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        throw GeminiError.apiError("File processing timed out")
    }

    private func deleteUploadedFile(apiKey: String, fileURI: String) async {
        let resourceName: String
        if let range = fileURI.range(of: "/files/") {
            resourceName = String(fileURI[range.lowerBound...].dropFirst())
        } else if fileURI.hasPrefix("files/") {
            resourceName = fileURI
        } else {
            return
        }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/files/\(resourceName)?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try? await session.data(for: request)
    }

    private func generateJSON(model: String, apiKey: String, prompt: String, schema: [String: Any]) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.3,
                "responseMimeType": "application/json",
                "responseSchema": schema
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(message)
        }
        return try parsePlainTextResponse(data)
    }

    private func generatePlainText(model: String, apiKey: String, prompt: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.3]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(message)
        }
        return try parsePlainTextResponse(data)
    }

    private func parsePlainTextResponse(_ data: Data) throws -> String {
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = jsonObject["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw GeminiError.apiError(message)
        }

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

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw GeminiError.invalidResponse
        }
        return text
    }

    private var journalSummarySchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "summary": ["type": "string"],
                "upcomingPlans": ["type": "string", "nullable": true]
            ],
            "required": ["summary"]
        ]
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
