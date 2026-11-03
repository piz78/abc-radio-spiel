import XCTest
@testable import ABCCore

final class QuestionBankTests: XCTestCase {
    /// Lädt die echte Fragen-Datei aus dem App-Ordner.
    static func loadBank() throws -> QuestionBank {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ABCSpiel/Resources/fragen.txt")
        return QuestionBank(text: try String(contentsOf: url, encoding: .utf8))
    }

    func testParsesLines() {
        let bank = QuestionBank(text: """
        # Kommentar
        B | Hauptstadt? | Bern | Bärn; Berne

        A | Fluss? | Aare
        kaputt
        """)
        XCTAssertEqual(bank.questions.count, 2)
        XCTAssertEqual(bank.questions[0].letter, "B")
        XCTAssertEqual(bank.questions[0].alternatives, ["Bärn", "Berne"])
        XCTAssertEqual(bank.questions[1].alternatives, [])
        XCTAssertEqual(bank.letters, ["A", "B"])
    }

    func testRealDatabaseIsConsistent() throws {
        let bank = try Self.loadBank()
        XCTAssertGreaterThan(bank.questions.count, 500)
        for question in bank.questions {
            let first = AnswerMatcher.normalize(question.answer).prefix(1).uppercased()
            XCTAssertEqual(first, question.letter, "«\(question.answer)» passt nicht zu \(question.letter)")
        }
        for letter in bank.letters {
            XCTAssertGreaterThanOrEqual(bank.questions(for: letter).count, 20, "Zu wenige Fragen für \(letter)")
        }
        XCTAssertEqual(Set(bank.questions.map(\.id)).count, bank.questions.count, "IDs müssen eindeutig sein")
    }
}

final class CardGeneratorTests: XCTestCase {
    func testCardHasQuestionsOfLetter() throws {
        let generator = CardGenerator(bank: try QuestionBankTests.loadBank())
        var rng = SeededGenerator(seed: 42)
        let card = try XCTUnwrap(generator.makeCard(using: &rng))
        XCTAssertTrue((20...25).contains(card.questions.count))
        XCTAssertTrue(card.questions.allSatisfy { $0.letter == card.letter })
        XCTAssertEqual(Set(card.questions.map(\.id)).count, card.questions.count)
    }

    func testAvoidsRecentLetters() throws {
        let generator = CardGenerator(bank: try QuestionBankTests.loadBank())
        let recent = ["A", "B", "C", "D", "E", "F"]
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<50 {
            let card = try XCTUnwrap(generator.makeCard(avoiding: recent, using: &rng))
            XCTAssertFalse(recent.contains(card.letter))
        }
    }

    func testFixedLetterAndHardLetterFilter() throws {
        var generator = CardGenerator(bank: try QuestionBankTests.loadBank())
        var rng = SeededGenerator(seed: 1)
        XCTAssertEqual(generator.makeCard(letter: "z", using: &rng)?.letter, "Z")
        generator.includeHardLetters = false
        XCTAssertTrue(generator.eligibleLetters.allSatisfy { !CardGenerator.hardLetters.contains($0) })
    }

    func testSeededGeneratorIsDeterministic() throws {
        let generator = CardGenerator(bank: try QuestionBankTests.loadBank())
        var a = SeededGenerator(seed: 99), b = SeededGenerator(seed: 99)
        XCTAssertEqual(generator.makeCard(using: &a)?.questions.map(\.id),
                       generator.makeCard(using: &b)?.questions.map(\.id))
    }
}

final class AnswerMatcherTests: XCTestCase {
    func testNormalize() {
        XCTAssertEqual(AnswerMatcher.normalize("  Zürich!  Straße "), "zurich strasse")
    }

    func testExactAndFuzzyMatches() {
        XCTAssertTrue(AnswerMatcher.matches("Bern", accepted: ["Bern"]))
        XCTAssertTrue(AnswerMatcher.matches("ähm ich glaube Bern", accepted: ["Bern"]))
        XCTAssertTrue(AnswerMatcher.matches("Matterhorn", accepted: ["Matterhorn"]))
        XCTAssertTrue(AnswerMatcher.matches("Materhorn", accepted: ["Matterhorn"]))
        XCTAssertTrue(AnswerMatcher.matches("Eis bär", accepted: ["Eisbär"]))
        XCTAssertTrue(AnswerMatcher.matches("New York", accepted: ["New York"]))
        XCTAssertTrue(AnswerMatcher.matches("Bärn", accepted: ["Bern", "Bärn"]))
    }

    func testRejectsWrongAnswers() {
        XCTAssertFalse(AnswerMatcher.matches("Basel", accepted: ["Bern"]))
        XCTAssertFalse(AnswerMatcher.matches("", accepted: ["Bern"]))
        XCTAssertFalse(AnswerMatcher.matches("Eis", accepted: ["Ei"]))
    }

    func testPass() {
        XCTAssertTrue(AnswerMatcher.isPass("weiter"))
        XCTAssertTrue(AnswerMatcher.isPass("äh passe"))
        XCTAssertFalse(AnswerMatcher.isPass("Bern"))
    }

    func testLevenshtein() {
        XCTAssertEqual(AnswerMatcher.levenshtein("kitten", "sitting"), 3)
        XCTAssertEqual(AnswerMatcher.levenshtein("", "abc"), 3)
        XCTAssertEqual(AnswerMatcher.levenshtein("abc", "abc"), 0)
    }
}

final class GameRoundTests: XCTestCase {
    private func makeCard(count: Int) -> Card {
        let questions = (0..<count).map {
            Question(id: "B-\($0)", letter: "B", prompt: "Frage \($0)?", answer: "B\($0)", alternatives: [])
        }
        return Card(letter: "B", questions: questions)
    }

    func testScoringAndTimeUp() {
        let start = Date(timeIntervalSince1970: 1000)
        var round = GameRound(card: makeCard(count: 10), duration: 45)
        XCTAssertNil(round.currentQuestion)
        round.start(at: start)
        XCTAssertEqual(round.currentQuestion?.id, "B-0")
        XCTAssertTrue(round.answer(.correct, at: start.addingTimeInterval(2)))
        XCTAssertTrue(round.answer(.passed, at: start.addingTimeInterval(4)))
        XCTAssertTrue(round.answer(.correct, at: start.addingTimeInterval(6)))
        XCTAssertEqual(round.score, 2)
        XCTAssertEqual(round.remaining(at: start.addingTimeInterval(10)), 35, accuracy: 0.001)

        // Nach Ablauf zählt eine Antwort nicht mehr.
        XCTAssertFalse(round.answer(.correct, at: start.addingTimeInterval(46)))
        XCTAssertTrue(round.isFinished)
        XCTAssertEqual(round.score, 2)
        XCTAssertEqual(round.log.last?.outcome, .open)
        XCTAssertEqual(round.remaining(at: start.addingTimeInterval(100)), 0)
    }

    func testFinishesWhenOutOfQuestions() {
        let start = Date()
        var round = GameRound(card: makeCard(count: 2), duration: 45)
        round.start(at: start)
        round.answer(.correct, at: start)
        round.answer(.correct, at: start)
        XCTAssertTrue(round.isFinished)
        XCTAssertEqual(round.score, 2)
        XCTAssertEqual(round.log.count, 2)
    }

    func testToggleCorrection() {
        let start = Date()
        var round = GameRound(card: makeCard(count: 5), duration: 45)
        round.start(at: start)
        round.answer(.passed, at: start)
        round.finish(at: start.addingTimeInterval(1))
        round.toggleOutcome(of: "B-0")
        XCTAssertEqual(round.score, 1)
        round.toggleOutcome(of: "B-0")
        XCTAssertEqual(round.score, 0)
    }
}

final class ModeratorAndStatsTests: XCTestCase {
    func testVerdictMentionsScore() {
        var rng = SeededGenerator(seed: 3)
        for score in 0...25 {
            let line = ModeratorScript.verdict(score: score, target: 12, using: &rng)
            XCTAssertTrue(line.display.contains("\(score)"))
        }
        let win = ModeratorScript.verdict(score: 12, target: 12, using: &rng).display
        XCTAssertTrue(win.contains("gwunne") || win.contains("Siig"))
    }

    func testLetterAnnouncementUsesSpokenName() {
        var rng = SeededGenerator(seed: 5)
        let line = ModeratorScript.letterAnnouncement("W", using: &rng)
        XCTAssertTrue(line.display.contains("W"))
        XCTAssertTrue(line.spoken.contains("We"))
        XCTAssertTrue(line.spoken.contains("Winterthur"))
    }

    func testStats() {
        var stats = GameStats()
        stats.record(letter: "A", score: 13, target: 12)
        stats.record(letter: "B", score: 7, target: 12)
        stats.record(letter: "A", score: 9, target: 12)
        XCTAssertEqual(stats.gamesPlayed, 3)
        XCTAssertEqual(stats.wins, 1)
        XCTAssertEqual(stats.bestScore, 13)
        XCTAssertEqual(stats.bestByLetter["A"], 13)
        XCTAssertEqual(stats.recentLetters, ["A", "B"])
        XCTAssertEqual(stats.averageScore, 29.0 / 3.0, accuracy: 0.001)
    }
}
