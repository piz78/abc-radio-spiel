import Foundation
import Observation

enum GameMode: String, Identifiable {
    case solo      // die App moderiert, Lösungen verborgen
    case friends   // du moderierst für jemand anders, Lösungen sichtbar
    var id: String { rawValue }
}

/// Zentrale App-Daten: Fragen, Einstellungen, Statistik, Moderatorstimme.
@MainActor
@Observable
final class AppModel {
    let bank: QuestionBank
    let settings = AppSettings()
    let voice = ModeratorVoice()
    let clips = ClipLibrary()
    private(set) var stats: GameStats

    private let statsKey = "gameStats"

    init() {
        if let url = Bundle.main.url(forResource: "fragen", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            bank = QuestionBank(text: text)
        } else {
            bank = QuestionBank(questions: [])
        }
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(GameStats.self, from: data) {
            stats = decoded
        } else {
            stats = GameStats()
        }
        voice.clips = clips
    }

    var generator: CardGenerator {
        var generator = CardGenerator(bank: bank)
        generator.includeHardLetters = settings.includeHardLetters
        return generator
    }

    func newCard(letter: String? = nil) -> Card? {
        generator.makeCard(letter: letter, avoiding: stats.recentLetters)
    }

    /// Überträgt die aktuellen Einstellungen auf Stimme und Töne.
    func applySettings() {
        voice.isEnabled = settings.voiceEnabled
        voice.voiceIdentifier = settings.voiceIdentifier
        voice.rate = Float(settings.speechRate)
        clips.isEnabled = settings.useOwnVoice
        SoundFX.isEnabled = settings.soundEnabled
    }

    func record(letter: String, score: Int) {
        stats.record(letter: letter, score: score, target: settings.targetScore)
        saveStats()
    }

    func resetStats() {
        stats = GameStats()
        saveStats()
    }

    private func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }
}
