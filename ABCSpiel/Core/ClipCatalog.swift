import Foundation

extension Question {
    /// Fester Clip-Schlüssel, z.B. `q-b-bern` (unabhängig von der Zeilennummer).
    var clipKey: String {
        let slug = AnswerMatcher.normalize(answer).replacingOccurrences(of: " ", with: "-")
        return "q-\(letter.lowercased())-\(slug)"
    }

    var clip: Clip { Clip(key: clipKey, text: prompt, group: ModeratorScript.Group.questions(letter)) }
}

/// Liste aller Sprech-Clips (Bausteine statt ganzer Sätze mit Zahlen) – die gemeinsame Quelle für die App (Aufnahme-Studio)
/// und das Mac-Skript `tools/voice/generate_clips.py` (via `swift run abc-clips`).
public enum ClipCatalog {
    static func moderatorClips(letters: [String]) -> [Clip] {
        typealias S = ModeratorScript
        var result: [Clip] = []
        result += S.greetingClips
        result.append(S.probeClip)
        result.append(S.rulesIntroClip)
        // Sätze mit Zahlen werden aus Bausteinen zusammengesetzt (SBB-Prinzip).
        result += [S.rulesSecondsPreClip, S.rulesSecondsPostClip, S.rulesTargetPreClip, S.rulesTargetPostClip]
        result.append(S.rulesPassClip)
        result += S.announceClips
        result += letters.map(S.letterClip)
        result += S.countdownClips
        result += S.timeUpClips
        result.append(S.outOfQuestionsClip)
        result += S.VerdictBand.allCases.flatMap(\.clips)
        result += [S.scorePointsClip, S.scoreOneClip]
        result += S.numbers.compactMap(S.numberClip)
        return result
    }

    static func questionClips(_ bank: QuestionBank) -> [Clip] {
        bank.letters.flatMap { bank.questions(for: $0).map(\.clip) }
    }

    /// Alle Clips: Referenz-Sätze, Moderator, Fragen.
    static func all(bank: QuestionBank) -> [Clip] {
        ModeratorScript.referenceClips + moderatorClips(letters: bank.letters) + questionClips(bank)
    }

    /// JSON-Manifest für das Generator-Skript.
    public static func manifestJSON(questionsText: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(all(bank: QuestionBank(text: questionsText)))
    }
}
