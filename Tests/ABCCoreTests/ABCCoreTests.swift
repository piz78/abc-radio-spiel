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

    /// «B wie …» soll keine Antwort verraten.
    func testLetterExamplesAreNoAnswers() throws {
        let bank = try Self.loadBank()
        let answers = Set(bank.questions.flatMap(\.acceptedAnswers).map(AnswerMatcher.normalize))
        for (letter, example) in ModeratorScript.letterExamples {
            XCTAssertFalse(answers.contains(AnswerMatcher.normalize(example)),
                           "«\(letter) wie \(example)» ist eine Antwort in fragen.txt")
        }
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
        XCTAssertTrue(win.lowercased().contains("gwunne") || win.contains("Siig"))
    }

    func testLetterAnnouncementUsesSpokenName() {
        var rng = SeededGenerator(seed: 5)
        let line = ModeratorScript.letterAnnouncement("W", using: &rng)
        XCTAssertTrue(line.display.contains("W"))
        XCTAssertTrue(line.spoken.contains("We"))
        XCTAssertTrue(line.spoken.contains(ModeratorScript.letterExamples["W"]!))
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

final class ClipCatalogTests: XCTestCase {
    func testKeysAreUniqueAndFileSafe() throws {
        let clips = ClipCatalog.all(bank: try QuestionBankTests.loadBank())
        let keys = clips.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "Doppelte Clip-Schlüssel")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        for key in keys {
            XCTAssertFalse(key.isEmpty)
            XCTAssertTrue(key.unicodeScalars.allSatisfy(allowed.contains), "Ungültiger Schlüssel: \(key)")
        }
        XCTAssertTrue(keys.contains("q-b-bern"))
        XCTAssertTrue(keys.contains("q-u-u-boot"))
    }

    func testEveryPlayedClipIsInCatalog() throws {
        let bank = try QuestionBankTests.loadBank()
        let keys = Set(ClipCatalog.all(bank: bank).map(\.key))
        var lines: [ModeratorLine] = ModeratorScript.greetings + ModeratorScript.countdown + ModeratorScript.timeUp
        lines += [ModeratorScript.outOfQuestions, ModeratorScript.probe]
        for seconds in GameOptions.roundSecondsChoices {
            for target in GameOptions.targetRange {
                lines.append(ModeratorScript.rules(seconds: seconds, target: target))
            }
        }
        var rng = SeededGenerator(seed: 11)
        for letter in bank.letters {
            for _ in 0..<5 { lines.append(ModeratorScript.letterAnnouncement(letter, using: &rng)) }
        }
        for target in GameOptions.targetRange {
            for score in 0...25 {
                for _ in 0..<3 { lines.append(ModeratorScript.verdict(score: score, target: target, using: &rng)) }
            }
        }
        lines += bank.questions.map(ModeratorScript.questionLine)
        for line in lines {
            for clip in line.clips {
                if let blocks = clip.blocks {
                    // Satz aus Bausteinen: jeder Baustein muss aufnehmbar sein.
                    for block in blocks {
                        XCTAssertTrue(keys.contains(block.key), "Baustein fehlt im Katalog: \(block.key) (\(clip.key))")
                    }
                } else {
                    XCTAssertTrue(keys.contains(clip.key), "Clip fehlt im Katalog: \(clip.key)")
                }
            }
        }
    }

    func testNumberSentencesHaveBlocks() {
        // Alle Zahlen, die im Spiel vorkommen, lassen sich aus Bausteinen zusammensetzen.
        for seconds in GameOptions.roundSecondsChoices {
            let clip = ModeratorScript.rulesSecondsClip(seconds)
            XCTAssertEqual(clip.blocks?.map(\.key), ["rules-seconds-pre", "zahl-\(seconds)", "rules-seconds-post"])
        }
        for target in GameOptions.targetRange {
            XCTAssertEqual(ModeratorScript.rulesTargetClip(target).blocks?.count, 3)
        }
        for score in GameOptions.scoreRange {
            XCTAssertNotNil(ModeratorScript.scoreClip(score).blocks, "Kein Baustein für \(score) Pünkt")
        }
        XCTAssertEqual(ModeratorScript.scoreClip(1).blocks?.map(\.key), ["score-one"])
        XCTAssertEqual(ModeratorScript.scoreClip(12).blocks?.map(\.text), ["zwölf", "… Pünkt."])
        // Ausserhalb der Bausteine: nur Sprachausgabe für den ganzen Satz.
        XCTAssertNil(ModeratorScript.scoreClip(77).blocks)
    }

    func testManifestJSON() throws {
        let data = try ClipCatalog.manifestJSON(questionsText: "B | Hauptstadt? | Bern\n")
        let decoded = try JSONDecoder().decode([Clip].self, from: data)
        XCTAssertTrue(decoded.contains { $0.key == "q-b-bern" && $0.text == "Hauptstadt?" })
        XCTAssertTrue(decoded.contains { $0.key == "letter-b" })
        XCTAssertTrue(decoded.contains { $0.key.hasPrefix("ref-") })
        XCTAssertTrue(decoded.contains { $0.key == "zahl-45" && $0.text == "föifevierzg" })
        XCTAssertFalse(decoded.contains { $0.key == "score-12" }, "Ganze Zahlen-Sätze werden nicht mehr aufgenommen")
    }
}
