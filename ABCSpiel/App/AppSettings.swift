import Foundation
import Observation

/// Benutzereinstellungen, in UserDefaults gespeichert.
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var roundSeconds: Int { didSet { defaults.set(roundSeconds, forKey: Keys.roundSeconds) } }
    var targetScore: Int { didSet { defaults.set(targetScore, forKey: Keys.targetScore) } }
    var voiceEnabled: Bool { didSet { defaults.set(voiceEnabled, forKey: Keys.voiceEnabled) } }
    var voiceIdentifier: String? { didSet { defaults.set(voiceIdentifier, forKey: Keys.voiceIdentifier) } }
    var speechRate: Double { didSet { defaults.set(speechRate, forKey: Keys.speechRate) } }
    var listeningEnabled: Bool { didSet { defaults.set(listeningEnabled, forKey: Keys.listeningEnabled) } }
    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) } }
    var includeHardLetters: Bool { didSet { defaults.set(includeHardLetters, forKey: Keys.includeHardLetters) } }
    var explainRules: Bool { didSet { defaults.set(explainRules, forKey: Keys.explainRules) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.roundSeconds: 45,
            Keys.targetScore: 12,
            Keys.voiceEnabled: true,
            Keys.speechRate: 0.52,
            Keys.listeningEnabled: false,
            Keys.soundEnabled: true,
            Keys.includeHardLetters: true,
            Keys.explainRules: true,
        ])
        roundSeconds = defaults.integer(forKey: Keys.roundSeconds)
        targetScore = defaults.integer(forKey: Keys.targetScore)
        voiceEnabled = defaults.bool(forKey: Keys.voiceEnabled)
        voiceIdentifier = defaults.string(forKey: Keys.voiceIdentifier)
        speechRate = defaults.double(forKey: Keys.speechRate)
        listeningEnabled = defaults.bool(forKey: Keys.listeningEnabled)
        soundEnabled = defaults.bool(forKey: Keys.soundEnabled)
        includeHardLetters = defaults.bool(forKey: Keys.includeHardLetters)
        explainRules = defaults.bool(forKey: Keys.explainRules)
    }

    private enum Keys {
        static let roundSeconds = "roundSeconds"
        static let targetScore = "targetScore"
        static let voiceEnabled = "voiceEnabled"
        static let voiceIdentifier = "voiceIdentifier"
        static let speechRate = "speechRate"
        static let listeningEnabled = "listeningEnabled"
        static let soundEnabled = "soundEnabled"
        static let includeHardLetters = "includeHardLetters"
        static let explainRules = "explainRules"
    }
}
