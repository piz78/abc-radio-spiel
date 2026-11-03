import AVFoundation

/// Die Stimme des Moderators: spielt Clips (eigene/generierte Aufnahmen) ab
/// und fällt für fehlende Clips auf die iOS-Sprachausgabe zurück.
@MainActor
final class ModeratorVoice: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var speechContinuations: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]
    private var player: AVAudioPlayer?
    private var playerContinuation: CheckedContinuation<Void, Never>?
    private var lineTask: Task<Void, Never>?
    private var generation = 0

    var isEnabled = true
    var voiceIdentifier: String?
    /// 0.0 … 1.0 (AVSpeechUtterance-Skala)
    var rate: Float = 0.52
    var clips: ClipLibrary?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Stimmen

    /// Alle deutschen Stimmen, Schweizer Stimmen und bessere Qualität zuerst.
    static func germanVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("de") }
            .sorted { a, b in
                let aCH = a.language == "de-CH", bCH = b.language == "de-CH"
                if aCH != bCH { return aCH }
                if a.quality != b.quality { return a.quality.rawValue > b.quality.rawValue }
                return a.name < b.name
            }
    }

    static func describe(_ voice: AVSpeechSynthesisVoice) -> String {
        let region: String
        switch voice.language {
        case "de-CH": region = "🇨🇭"
        case "de-AT": region = "🇦🇹"
        default: region = "🇩🇪"
        }
        let quality: String
        switch voice.quality {
        case .premium: quality = " (Premium)"
        case .enhanced: quality = " (Verbesseret)"
        default: quality = ""
        }
        return "\(region) \(voice.name)\(quality)"
    }

    var currentVoice: AVSpeechSynthesisVoice? {
        if let id = voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        return Self.germanVoices().first ?? AVSpeechSynthesisVoice(language: "de-DE")
    }

    // MARK: Öffentliche Schnittstelle

    /// Spricht sofort (unterbricht Laufendes) und wartet nicht.
    func speak(_ line: ModeratorLine) {
        guard isEnabled else { return }
        stop()
        let myGeneration = generation
        lineTask = Task { await perform(line, generation: myGeneration) }
    }

    /// Spricht und wartet, bis der Satz fertig (oder abgebrochen) ist.
    func say(_ line: ModeratorLine) async {
        guard isEnabled, !Task.isCancelled else { return }
        stop()
        await perform(line, generation: generation)
    }

    func stop() {
        generation += 1
        lineTask?.cancel()
        lineTask = nil
        player?.stop()
        player = nil
        playerContinuation?.resume()
        playerContinuation = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        // Wartende sofort freigeben, damit kein Ablauf hängen bleibt.
        let pending = speechContinuations.values
        speechContinuations.removeAll()
        pending.forEach { $0.resume() }
    }

    // MARK: Ablauf

    private func perform(_ line: ModeratorLine, generation myGeneration: Int) async {
        for clip in line.clips {
            guard generation == myGeneration, !Task.isCancelled else { return }
            if let url = clips?.url(for: clip.key) {
                await play(url)
            } else {
                await utter(clip.text)
            }
        }
    }

    private func play(_ url: URL) async {
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        newPlayer.delegate = self
        player = newPlayer
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            playerContinuation = continuation
            if !newPlayer.play() {
                finishPlayer(ObjectIdentifier(newPlayer))
            }
        }
    }

    private func finishPlayer(_ id: ObjectIdentifier) {
        guard let player, ObjectIdentifier(player) == id else { return }
        self.player = nil
        playerContinuation?.resume()
        playerContinuation = nil
    }

    private func utter(_ text: String) async {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = currentVoice
        utterance.rate = rate
        utterance.pitchMultiplier = 1.05
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.05
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            speechContinuations[ObjectIdentifier(utterance)] = continuation
            synthesizer.speak(utterance)
        }
    }

    private func finishSpeech(_ key: ObjectIdentifier) {
        speechContinuations.removeValue(forKey: key)?.resume()
    }

    // MARK: Delegates

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in self.finishSpeech(key) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in self.finishSpeech(key) }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.finishPlayer(id) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.finishPlayer(id) }
    }
}
