import AVFoundation
import Speech

@Observable
final class SpeechService {
    enum SpeechError: LocalizedError {
        case notAuthorized
        case unavailable
        case engineFailure

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Speech recognition permission denied."
            case .unavailable: return "Speech recognition unavailable."
            case .engineFailure: return "Could not start audio engine."
            }
        }
    }

    private(set) var transcript = ""
    private(set) var isRecording = false
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var finalizeContinuation: CheckedContinuation<String, Never>?
    private var isWaitingForFinalize = false

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    @MainActor
    func startRecording() throws {
        guard authorizationStatus == .authorized else { throw SpeechError.notAuthorized }
        guard let speechRecognizer, speechRecognizer.isAvailable else { throw SpeechError.unavailable }

        stopRecordingInternal(cancelTask: true)
        isWaitingForFinalize = false

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { throw SpeechError.engineFailure }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal, self.isWaitingForFinalize {
                        self.completeFinalize(with: self.transcript)
                    }
                }
                if error != nil, self.isWaitingForFinalize {
                    self.completeFinalize(with: self.transcript)
                }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        transcript = ""
    }

    @MainActor
    func stopRecordingAndFinalize() async -> String {
        let snapshot = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isRecording else { return snapshot }

        isWaitingForFinalize = true
        isRecording = false
        recognitionRequest?.endAudio()

        let finalized: String = await withCheckedContinuation { continuation in
            finalizeContinuation = continuation
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if self.finalizeContinuation != nil {
                    self.completeFinalize(with: self.transcript.isEmpty ? snapshot : self.transcript)
                }
            }
        }

        return finalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    func currentTranscript() -> String {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    func clearTranscript() {
        transcript = ""
    }

    @MainActor
    private func completeFinalize(with text: String) {
        isWaitingForFinalize = false
        guard let continuation = finalizeContinuation else { return }
        finalizeContinuation = nil
        stopRecordingInternal(cancelTask: false)
        continuation.resume(returning: text)
    }

    @MainActor
    private func stopRecordingInternal(cancelTask: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        if cancelTask {
            recognitionTask?.cancel()
        }
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        isWaitingForFinalize = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
