import AVFoundation
import Foundation

@Observable
final class AudioRecordingService {
    enum RecordingError: LocalizedError {
        case permissionDenied
        case alreadyRecording
        case notRecording
        case setupFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Microphone permission denied."
            case .alreadyRecording: return "Already recording."
            case .notRecording: return "Not currently recording."
            case .setupFailed: return "Could not start audio recorder."
            }
        }
    }

    private(set) var isRecording = false
    private(set) var currentRecordingURL: URL?
    private(set) var recordingStartedAt: Date?
    private var recorder: AVAudioRecorder?
    private var durationTimer: Timer?

    private(set) var elapsedSeconds: TimeInterval = 0

    static var recordingsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    @MainActor
    func startRecording() throws -> URL {
        guard !isRecording else { throw RecordingError.alreadyRecording }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let fileURL = Self.recordingsDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        guard let recorder, recorder.prepareToRecord(), recorder.record() else {
            throw RecordingError.setupFailed
        }

        isRecording = true
        currentRecordingURL = fileURL
        recordingStartedAt = Date()
        elapsedSeconds = 0
        startDurationTimer()

        return fileURL
    }

    @MainActor
    func stopRecording() throws -> (url: URL, duration: TimeInterval) {
        guard isRecording, let recorder, let url = currentRecordingURL else {
            throw RecordingError.notRecording
        }

        recorder.stop()
        stopDurationTimer()

        let duration = elapsedSeconds
        isRecording = false
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return (url, duration)
    }

    @MainActor
    func cancelRecording() {
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recorder?.stop()
        recorder = nil
        stopDurationTimer()
        isRecording = false
        currentRecordingURL = nil
        recordingStartedAt = nil
        elapsedSeconds = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    static func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @MainActor
    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let started = self.recordingStartedAt else { return }
            Task { @MainActor in
                self.elapsedSeconds = Date().timeIntervalSince(started)
            }
        }
    }

    @MainActor
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}
