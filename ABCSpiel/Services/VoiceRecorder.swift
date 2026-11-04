import AVFoundation
import Observation

/// Nimmt einzelne Clips mit dem Mikrofon auf und spielt sie zur Kontrolle ab.
@MainActor
@Observable
final class VoiceRecorder: NSObject, AVAudioPlayerDelegate {
    private(set) var recordingKey: String?
    private(set) var playingKey: String?
    private(set) var level: Float = 0
    /// Erhöht sich bei jeder Änderung, damit Listen neu zeichnen.
    private(set) var revision = 0

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var meterTask: Task<Void, Never>?
    @ObservationIgnored private let library: ClipLibrary

    init(library: ClipLibrary) {
        self.library = library
    }

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func prepareSession() {
        AudioSession.configure(listening: true)
    }

    func toggleRecording(_ key: String) {
        if recordingKey == key {
            stopRecording()
        } else {
            startRecording(key)
        }
    }

    func startRecording(_ key: String) {
        stopRecording()
        stopPlaying()
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(key)-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let newRecorder = try? AVAudioRecorder(url: temp, settings: settings) else { return }
        newRecorder.isMeteringEnabled = true
        guard newRecorder.record() else { return }
        recorder = newRecorder
        recordingKey = key
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                let db = recorder.averagePower(forChannel: 0)
                self.level = max(0, min(1, (db + 50) / 50))
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    /// Stoppt die Aufnahme und speichert sie (Stille am Anfang/Ende weggeschnitten).
    /// Gibt `true` zurück, wenn eine Aufnahme gespeichert wurde.
    @discardableResult
    func stopRecording() -> Bool {
        meterTask?.cancel()
        meterTask = nil
        level = 0
        guard let recorder, let key = recordingKey else { return false }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        recordingKey = nil
        // Sehr kurze Aufnahmen (versehentlich getippt) verwerfen.
        guard duration > 0.4 else {
            try? FileManager.default.removeItem(at: recorder.url)
            return false
        }
        let target = library.recordingURL(for: key)
        try? FileManager.default.removeItem(at: target)
        if AudioTrimmer.trimSilence(source: recorder.url, destination: target) {
            try? FileManager.default.removeItem(at: recorder.url)
        } else {
            try? FileManager.default.moveItem(at: recorder.url, to: target)
        }
        revision += 1
        return true
    }

    func play(_ key: String, url: URL) {
        stopPlaying()
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        newPlayer.delegate = self
        player = newPlayer
        playingKey = key
        newPlayer.play()
    }

    func stopPlaying() {
        player?.stop()
        player = nil
        playingKey = nil
    }

    func delete(_ key: String) {
        library.deleteRecording(key)
        revision += 1
    }

    func tearDown() {
        stopRecording()
        stopPlaying()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.playingKey = nil
        }
    }
}
