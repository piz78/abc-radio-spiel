import Foundation

/// Vergleicht gesprochene Antworten (Transkript der Spracherkennung) unscharf mit der Lösung.
enum AnswerMatcher {
    /// Wörter, mit denen man passt.
    static let passWords: Set<String> = [
        "weiter", "wiiter", "witer", "wieder", "passe", "pass", "passen", "next", "nachste", "nochste",
    ]

    /// Kleinbuchstaben, ohne Akzente/Umlaute, nur Buchstaben/Ziffern, Wörter mit einem Leerzeichen getrennt.
    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased().replacingOccurrences(of: "ß", with: "ss")
        let folded = lowered.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_CH"))
        var cleaned = ""
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                cleaned.unicodeScalars.append(scalar)
            } else {
                cleaned.append(" ")
            }
        }
        return cleaned.split(separator: " ").joined(separator: " ")
    }

    /// Erlaubte Tippfehler-Distanz abhängig von der Wortlänge.
    static func tolerance(forLength length: Int) -> Int {
        switch length {
        case ..<4: return 0
        case 4...6: return 1
        case 7...10: return 2
        default: return 3
        }
    }

    /// Prüft, ob das Transkript eine der akzeptierten Antworten enthält.
    static func matches(_ transcript: String, accepted: [String]) -> Bool {
        let words = normalize(transcript).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return false }
        for answer in accepted {
            let answerWords = normalize(answer).split(separator: " ").map(String.init)
            guard !answerWords.isEmpty else { continue }
            let target = answerWords.joined()
            let tol = tolerance(forLength: target.count)
            // Fenster mit ähnlicher Wortanzahl (Komposita werden oft getrennt erkannt: «Eis bär»).
            let sizes = Set([answerWords.count, answerWords.count + 1, max(1, answerWords.count - 1)])
            for size in sizes where size <= words.count {
                for start in 0...(words.count - size) {
                    let candidate = words[start..<(start + size)].joined()
                    if abs(candidate.count - target.count) > tol { continue }
                    if levenshtein(candidate, target) <= tol { return true }
                }
            }
        }
        return false
    }

    /// Prüft, ob der Spieler passen will.
    static func isPass(_ transcript: String) -> Bool {
        normalize(transcript).split(separator: " ").contains { passWords.contains(String($0)) }
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
