import AVFoundation

/// Die Stimme des Moderators (Text-to-Speech).
@MainActor
final class ModeratorVoice: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuations: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]

    var isEnabled = true
    var voiceIdentifier: String?
    /// 0.0 … 1.0 (AVSpeechUtterance-Skala)
    var rate: Float = 0.52

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

    // MARK: Sprechen

    private func makeUtterance(_ text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = currentVoice
        utterance.rate = rate
        utterance.pitchMultiplier = 1.05
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.05
        return utterance
    }

    /// Spricht sofort (unterbricht Laufendes) und wartet nicht.
    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        stop()
        synthesizer.speak(makeUtterance(text))
    }

    /// Spricht und wartet, bis der Satz fertig (oder abgebrochen) ist.
    func say(_ text: String) async {
        guard isEnabled, !text.isEmpty, !Task.isCancelled else { return }
        stop()
        let utterance = makeUtterance(text)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            continuations[ObjectIdentifier(utterance)] = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        // Wartende sofort freigeben, damit kein Ablauf hängen bleibt.
        let pending = continuations.values
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }

    private func finish(_ key: ObjectIdentifier) {
        continuations.removeValue(forKey: key)?.resume()
    }

    // MARK: AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(key) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(key) }
    }
}
