import Foundation

/// Langzeit-Statistik des Spielers.
struct GameStats: Codable, Equatable, Sendable {
    var gamesPlayed = 0
    var wins = 0
    var bestScore = 0
    var totalCorrect = 0
    var bestByLetter: [String: Int] = [:]
    var recentLetters: [String] = []

    var averageScore: Double {
        gamesPlayed == 0 ? 0 : Double(totalCorrect) / Double(gamesPlayed)
    }

    mutating func record(letter: String, score: Int, target: Int) {
        gamesPlayed += 1
        totalCorrect += score
        if score >= target { wins += 1 }
        bestScore = max(bestScore, score)
        bestByLetter[letter] = max(bestByLetter[letter] ?? 0, score)
        recentLetters.removeAll { $0 == letter }
        recentLetters.insert(letter, at: 0)
        if recentLetters.count > 6 { recentLetters.removeLast(recentLetters.count - 6) }
    }
}
