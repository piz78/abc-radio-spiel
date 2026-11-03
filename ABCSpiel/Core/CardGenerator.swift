import Foundation

/// Erzeugt Spielkarten aus der Fragen-Datenbank.
struct CardGenerator: Sendable {
    /// Buchstaben, die im Radio eher selten vorkommen (wenige Begriffe).
    static let hardLetters: Set<String> = ["C", "I", "J", "Q", "U", "V", "X", "Y"]

    let bank: QuestionBank
    var questionsPerCard: Int = 25
    var minimumQuestions: Int = 15
    var includeHardLetters: Bool = true

    /// Buchstaben, die gezogen werden können.
    var eligibleLetters: [String] {
        bank.playableLetters(minimum: minimumQuestions).filter {
            includeHardLetters || !Self.hardLetters.contains($0)
        }
    }

    /// Zieht eine neue Karte.
    /// - Parameters:
    ///   - letter: Fester Buchstabe oder `nil` für Zufall.
    ///   - recent: Zuletzt gespielte Buchstaben (werden wenn möglich vermieden).
    func makeCard<R: RandomNumberGenerator>(
        letter: String? = nil,
        avoiding recent: [String] = [],
        using rng: inout R
    ) -> Card? {
        let chosen: String
        if let letter {
            chosen = letter.uppercased()
        } else {
            let all = eligibleLetters
            guard !all.isEmpty else { return nil }
            let fresh = all.filter { !recent.contains($0) }
            let pool = fresh.isEmpty ? all : fresh
            chosen = pool.randomElement(using: &rng)!
        }
        let pool = bank.questions(for: chosen)
        guard !pool.isEmpty else { return nil }
        let questions = Array(pool.shuffled(using: &rng).prefix(questionsPerCard))
        return Card(letter: chosen, questions: questions)
    }

    func makeCard(letter: String? = nil, avoiding recent: [String] = []) -> Card? {
        var rng = SystemRandomNumberGenerator()
        return makeCard(letter: letter, avoiding: recent, using: &rng)
    }
}
