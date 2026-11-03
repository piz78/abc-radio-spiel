import Foundation

/// Fragen-Datenbank. Quelle ist eine Textdatei mit einer Frage pro Zeile:
///
///     B | Hauptstadt vo de Schwiiz? | Bern | Bärn
///
/// Spalten: Buchstabe | Frage | Antwort | Alternativen (mit `;` getrennt, optional).
/// Leere Zeilen und Zeilen mit `#` am Anfang werden ignoriert.
struct QuestionBank: Sendable {
    let questions: [Question]
    private let byLetter: [String: [Question]]

    init(questions: [Question]) {
        self.questions = questions
        self.byLetter = Dictionary(grouping: questions, by: \.letter)
    }

    init(text: String) {
        self.init(questions: QuestionBank.parse(text))
    }

    /// Alle Buchstaben, sortiert.
    var letters: [String] { byLetter.keys.sorted() }

    func questions(for letter: String) -> [Question] {
        byLetter[letter.uppercased()] ?? []
    }

    /// Buchstaben mit mindestens `minimum` Fragen.
    func playableLetters(minimum: Int) -> [String] {
        letters.filter { questions(for: $0).count >= minimum }
    }

    static func parse(_ text: String) -> [Question] {
        var result: [Question] = []
        for (lineNumber, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 3, !parts[0].isEmpty, !parts[1].isEmpty, !parts[2].isEmpty else { continue }
            let letter = parts[0].uppercased()
            let alternatives: [String]
            if parts.count >= 4 {
                alternatives = parts[3]
                    .components(separatedBy: ";")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } else {
                alternatives = []
            }
            result.append(Question(
                id: "\(letter)-\(lineNumber + 1)",
                letter: letter,
                prompt: parts[1],
                answer: parts[2],
                alternatives: alternatives
            ))
        }
        return result
    }
}
