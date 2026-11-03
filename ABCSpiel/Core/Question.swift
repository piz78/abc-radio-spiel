import Foundation

/// Eine einzelne Frage einer ABC-Karte. Die Antwort beginnt immer mit `letter`.
struct Question: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let letter: String
    let prompt: String
    let answer: String
    let alternatives: [String]

    /// Alle Antworten, die als richtig gelten.
    var acceptedAnswers: [String] { [answer] + alternatives }
}

/// Eine generierte Spielkarte: ein Buchstabe und eine gemischte Fragenliste.
struct Card: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let letter: String
    let questions: [Question]

    init(id: UUID = UUID(), letter: String, questions: [Question]) {
        self.id = id
        self.letter = letter
        self.questions = questions
    }

    /// Text-Darstellung zum Teilen/Ausdrucken.
    var shareText: String {
        var lines = ["ABC – Buechstabe \(letter)", ""]
        for (i, q) in questions.enumerated() {
            lines.append("\(i + 1). \(q.prompt) → \(q.answer)")
        }
        return lines.joined(separator: "\n")
    }
}
