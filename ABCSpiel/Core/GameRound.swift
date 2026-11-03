import Foundation

enum AnswerOutcome: String, Codable, Sendable {
    case correct   // richtig beantwortet
    case passed    // «wiiter» – gepasst
    case open      // Zeit abgelaufen während der Frage
}

struct AnsweredQuestion: Identifiable, Hashable, Codable, Sendable {
    var id: String { question.id }
    let question: Question
    var outcome: AnswerOutcome
}

/// Eine Spielrunde: reiner Wert-Typ, die Zeit wird von aussen übergeben (testbar).
struct GameRound: Sendable {
    let card: Card
    let duration: TimeInterval
    private(set) var startedAt: Date?
    private(set) var endedAt: Date?
    private(set) var log: [AnsweredQuestion] = []
    private(set) var currentIndex = 0

    init(card: Card, duration: TimeInterval = 45) {
        self.card = card
        self.duration = duration
    }

    var isRunning: Bool { startedAt != nil && endedAt == nil }
    var isFinished: Bool { endedAt != nil }

    var currentQuestion: Question? {
        guard isRunning, currentIndex < card.questions.count else { return nil }
        return card.questions[currentIndex]
    }

    var score: Int { log.filter { $0.outcome == .correct }.count }
    var passedCount: Int { log.filter { $0.outcome == .passed }.count }

    mutating func start(at date: Date) {
        guard startedAt == nil else { return }
        startedAt = date
    }

    func remaining(at date: Date) -> TimeInterval {
        guard let startedAt else { return duration }
        let end = endedAt ?? date
        return max(0, duration - end.timeIntervalSince(startedAt))
    }

    /// Wertet die aktuelle Frage. Gibt `false` zurück, wenn nichts mehr zu werten war.
    @discardableResult
    mutating func answer(_ outcome: AnswerOutcome, at date: Date) -> Bool {
        guard isRunning else { return false }
        if remaining(at: date) <= 0 {
            finish(at: date)
            return false
        }
        guard let question = currentQuestion else { return false }
        log.append(AnsweredQuestion(question: question, outcome: outcome))
        currentIndex += 1
        if currentIndex >= card.questions.count {
            finish(at: date)
        }
        return true
    }

    /// Beendet die Runde. Eine gerade gestellte Frage wird als «offen» protokolliert.
    mutating func finish(at date: Date) {
        guard isRunning else { return }
        if currentIndex < card.questions.count {
            log.append(AnsweredQuestion(question: card.questions[currentIndex], outcome: .open))
            currentIndex += 1
        }
        if let startedAt {
            endedAt = min(date, startedAt.addingTimeInterval(duration))
        } else {
            endedAt = date
        }
    }

    /// Nachträgliche Korrektur im Resultat: richtig ↔ nicht richtig.
    mutating func toggleOutcome(of questionID: String) {
        guard let i = log.firstIndex(where: { $0.id == questionID }) else { return }
        log[i].outcome = log[i].outcome == .correct ? .passed : .correct
    }
}
