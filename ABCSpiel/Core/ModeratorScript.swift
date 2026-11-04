import Foundation

/// Ein Sprech-Baustein mit festem Schlüssel. Zu jedem Schlüssel kann es eine Audiodatei geben
/// (eigene Aufnahme oder mit dem Stimm-Klon generiert); sonst liest die iOS-Stimme `text`.
///
/// Ein Clip kann zusätzlich aus **Bausteinen** bestehen (wie die SBB-Ansagen): z.B.
/// «Du hesch» + «föifevierzg» + «Sekunde.». Gibt es keine Aufnahme für den ganzen Satz,
/// aber für alle Bausteine, werden diese nacheinander abgespielt.
struct Clip: Hashable, Codable, Sendable {
    let key: String
    let text: String
    let group: String
    /// Bausteine, aus denen der Satz zusammengesetzt werden kann (leer = keine).
    let blocks: [Clip]?

    init(key: String, text: String, group: String, blocks: [Clip]? = nil) {
        self.key = key
        self.text = text
        self.group = group
        self.blocks = blocks
    }
}

/// Ein Satz des Moderators: Anzeigetext und die Clips, die nacheinander gesprochen werden.
struct ModeratorLine: Equatable, Sendable {
    let display: String
    let clips: [Clip]

    init(display: String, clips: [Clip]) {
        self.display = display
        self.clips = clips
    }

    /// Ein Satz ohne Audiodatei (nur Sprachausgabe).
    init(_ text: String) {
        self.display = text
        self.clips = [Clip(key: "", text: text, group: "")]
    }

    /// Der ganze Text für die Sprachausgabe.
    var spoken: String { clips.map(\.text).joined(separator: " ") }
}

/// Spiel-Optionen, für die Clips erzeugt werden.
enum GameOptions {
    static let roundSecondsChoices = [30, 45, 60, 90]
    static let targetRange = 5...25
    static let scoreRange = 0...30
}

/// Alles, was der Moderator «Ruedi» sagt – in Schweizerdeutsch.
enum ModeratorScript {
    static let moderatorName = "Ruedi"

    enum Group {
        static let greeting = "Begrüessig"
        static let rules = "Regle"
        static let announce = "Buechstabe aasäge"
        static let letters = "Buechstabe"
        static let countdown = "Countdown"
        static let end = "Schluss"
        static let verdict = "Urteil"
        static let score = "Pünkt"
        static let numbers = "Zahle"
        static let reference = "Referenz für de Stimm-Klon"
        static func questions(_ letter: String) -> String { "Frage \(letter)" }
    }

    /// Aussprache der Buchstaben.
    static let letterNames: [String: String] = [
        "A": "A", "B": "Be", "C": "Ze", "D": "De", "E": "E", "F": "Eff", "G": "Ge",
        "H": "Ha", "I": "I", "J": "Jott", "K": "Ka", "L": "Ell", "M": "Emm", "N": "Enn",
        "O": "O", "P": "Pe", "Q": "Ku", "R": "Err", "S": "Ess", "T": "Te", "U": "U",
        "V": "Fau", "W": "We", "X": "Ix", "Y": "Üpsilon", "Z": "Zett",
    ]

    /// «B wie Bümpliz» – Schweizer Buchstabier-Beispiele. Keines davon ist eine Antwort in fragen.txt.
    static let letterExamples: [String: String] = [
        "A": "Altdorf", "B": "Bümpliz", "C": "Celerina", "D": "Dübendorf", "E": "Emme", "F": "Flüele", "G": "Gossau",
        "H": "Huttwil", "I": "Ittige", "J": "Jaunpass", "K": "Klosters", "L": "Langethal", "M": "Mendrisio", "N": "Nidau",
        "O": "Oensinge", "P": "Prattele", "Q": "Quinte", "R": "Rorschach", "S": "Spiez", "T": "Thusis", "U": "Unterseen",
        "V": "Vallorbe", "W": "Wädenswil", "X": "Xylophon", "Y": "Yverdon", "Z": "Zurzach",
    ]

    static func spokenLetter(_ letter: String) -> String {
        letterNames[letter.uppercased()] ?? letter
    }

    private static func clips(_ texts: [String], prefix: String, group: String) -> [Clip] {
        texts.enumerated().map { Clip(key: "\(prefix)-\($0.offset + 1)", text: $0.element, group: group) }
    }

    // MARK: - Begrüssung

    static let greetingClips = clips([
        "Hoi zäme und härzlich willkomme bim ABC!",
        "Grüezi mitenand – es isch Ziit für s'ABC!",
        "Sali! Schön, bisch wieder debii bim ABC.",
        "Guete Morge! Bisch parat für e Rundi ABC?",
        "Hallo, da isch de \(moderatorName) – und das isch s'ABC!",
    ], prefix: "greeting", group: Group.greeting)

    static var greetings: [ModeratorLine] {
        greetingClips.map { ModeratorLine(display: $0.text, clips: [$0]) }
    }

    static let probeClip = Clip(
        key: "probe",
        text: "Grüezi mitenand! Ich bi de \(moderatorName), din Moderator bim ABC.",
        group: Group.greeting
    )

    static var probe: ModeratorLine { ModeratorLine(display: probeClip.text, clips: [probeClip]) }

    // MARK: - Regeln

    static let rulesIntroClip = Clip(
        key: "rules-intro",
        text: "Ich stell dir Frage – und all Antworte fanged mit em gliiche Buechstabe aa.",
        group: Group.rules
    )
    static let rulesPassClip = Clip(
        key: "rules-pass",
        text: "Wenn d'öppis nid weisch, säg eifach «wiiter».",
        group: Group.rules
    )
    static let rulesSecondsPreClip = Clip(key: "rules-seconds-pre", text: "Du hesch …", group: Group.rules)
    static let rulesSecondsPostClip = Clip(key: "rules-seconds-post", text: "… Sekunde.", group: Group.rules)
    static let rulesTargetPreClip = Clip(key: "rules-target-pre", text: "Mit …", group: Group.rules)
    static let rulesTargetPostClip = Clip(key: "rules-target-post", text: "… richtige Antworte hesch gwunne.", group: Group.rules)

    /// «Du hesch 45 Sekunde.» – ganzer Satz oder aus Bausteinen.
    static func rulesSecondsClip(_ seconds: Int) -> Clip {
        Clip(key: "rules-seconds-\(seconds)", text: "Du hesch \(seconds) Sekunde.", group: Group.rules,
             blocks: numberClip(seconds).map { [rulesSecondsPreClip, $0, rulesSecondsPostClip] })
    }
    static func rulesTargetClip(_ target: Int) -> Clip {
        Clip(key: "rules-target-\(target)", text: "Mit \(target) richtige Antworte hesch gwunne.", group: Group.rules,
             blocks: numberClip(target).map { [rulesTargetPreClip, $0, rulesTargetPostClip] })
    }

    static func rules(seconds: Int, target: Int) -> ModeratorLine {
        let parts = [rulesIntroClip, rulesSecondsClip(seconds), rulesTargetClip(target), rulesPassClip]
        return ModeratorLine(display: parts.map(\.text).joined(separator: " "), clips: parts)
    }

    // MARK: - Buchstabe

    static let announceClips = clips([
        "Din Buechstabe isch:",
        "Hüt spilsch mit em",
        "Und de Buechstabe isch …",
    ], prefix: "announce", group: Group.announce)

    static func letterClip(_ letter: String) -> Clip {
        let l = letter.uppercased()
        let spoken = spokenLetter(l)
        let example = letterExamples[l] ?? l
        return Clip(key: "letter-\(l.lowercased())", text: "\(spoken). \(spoken) wie \(example)!", group: Group.letters)
    }

    static func letterAnnouncement<R: RandomNumberGenerator>(_ letter: String, using rng: inout R) -> ModeratorLine {
        let l = letter.uppercased()
        let intro = announceClips.randomElement(using: &rng)!
        let example = letterExamples[l] ?? l
        return ModeratorLine(display: "\(intro.text) \(l) – \(l) wie \(example)!", clips: [intro, letterClip(l)])
    }

    // MARK: - Countdown

    static let countdownClips = clips(["Achtung …", "fertig …", "los!"], prefix: "countdown", group: Group.countdown)

    static var countdown: [ModeratorLine] {
        countdownClips.map { ModeratorLine(display: $0.text, clips: [$0]) }
    }

    // MARK: - Schluss

    static let timeUpClips = clips([
        "Und Stopp – d'Ziit isch um!",
        "Piiip – fertig!",
        "Stopp! Das wärs gsi.",
    ], prefix: "timeup", group: Group.end)

    static var timeUp: [ModeratorLine] {
        timeUpClips.map { ModeratorLine(display: $0.text, clips: [$0]) }
    }

    static let outOfQuestionsClip = Clip(key: "outofquestions", text: "Wow – mir sind d'Frage usgange!", group: Group.end)
    static var outOfQuestions: ModeratorLine { ModeratorLine(display: outOfQuestionsClip.text, clips: [outOfQuestionsClip]) }

    static let scoreOneClip = Clip(key: "score-one", text: "Ein Punkt.", group: Group.score)
    static let scorePointsClip = Clip(key: "score-points", text: "… Pünkt.", group: Group.score)

    /// «12 Pünkt.» – ganzer Satz oder aus Bausteinen («zwölf» + «Pünkt.»).
    static func scoreClip(_ score: Int) -> Clip {
        let blocks: [Clip]? = score == 1 ? [scoreOneClip] : numberClip(score).map { [$0, scorePointsClip] }
        return Clip(key: "score-\(score)", text: score == 1 ? "1 Punkt." : "\(score) Pünkt.",
                    group: Group.score, blocks: blocks)
    }

    // MARK: - Zahle (Bausteine)

    /// Zahlen in Mundart – so, wie sie mitten im Satz gesprochen werden.
    static let numberWords: [Int: String] = [
        0: "null", 1: "eis", 2: "zwei", 3: "drü", 4: "vier", 5: "föif", 6: "sächs", 7: "sibe",
        8: "acht", 9: "nüün", 10: "zäh", 11: "elf", 12: "zwölf", 13: "drizäh", 14: "vierzäh",
        15: "füfzäh", 16: "sächzäh", 17: "sibzäh", 18: "achtzäh", 19: "nüünzäh", 20: "zwänzg",
        21: "einezwänzg", 22: "zweiezwänzg", 23: "drüezwänzg", 24: "vierezwänzg", 25: "föifezwänzg",
        26: "sächsezwänzg", 27: "sibenezwänzg", 28: "achtezwänzg", 29: "nüünezwänzg", 30: "drissg",
        45: "föifevierzg", 60: "sächzg", 90: "nünzg",
    ]

    /// Alle Zahlen, für die es Bausteine gibt (aufsteigend).
    static var numbers: [Int] { numberWords.keys.sorted() }

    /// Baustein für eine Zahl – oder `nil`, wenn es dafür keinen gibt.
    static func numberClip(_ n: Int) -> Clip? {
        numberWords[n].map { Clip(key: "zahl-\(n)", text: $0, group: Group.numbers) }
    }

    enum VerdictBand: String, CaseIterable {
        case low, mid, close, win, legend

        static func of(score: Int, target: Int) -> VerdictBand {
            switch score {
            case ..<(target / 3): return .low
            case ..<(target * 2 / 3): return .mid
            case ..<target: return .close
            case ..<(target + 5): return .win
            default: return .legend
            }
        }

        var texts: [String] {
            switch self {
            case .low: return ["Hoppla – das isch hüt nid din Buechstabe gsi. Nomal probiere!",
                               "Gäll, da hets di chli verwütscht. Grad nomal!"]
            case .mid: return ["Nid schlächt, aber da liit no meh drin!",
                               "Es guets Fundament – s'nächscht Mal gits meh!"]
            case .close: return ["Knapp verbii – so nöch!",
                                 "Oh nei, es hät ganz knapp nid glanget!"]
            case .win: return ["Gwunne! Gratuliere, du hesch s'ABC gschafft!",
                               "Bravo, das isch e Siig. Du chasch stolz sii!"]
            case .legend: return ["Wahnsinn! Du bisch e richtigi ABC-Legände!",
                                  "Sone Resultat gits nid all Tag – Huet ab!"]
            }
        }

        var clips: [Clip] {
            texts.enumerated().map {
                Clip(key: "verdict-\(rawValue)-\($0.offset + 1)", text: $0.element, group: Group.verdict)
            }
        }
    }

    static func verdict<R: RandomNumberGenerator>(score: Int, target: Int, using rng: inout R) -> ModeratorLine {
        let comment = VerdictBand.of(score: score, target: target).clips.randomElement(using: &rng)!
        let points = score == 1 ? "1 Punkt" : "\(score) Pünkt"
        return ModeratorLine(display: "\(points) – \(comment.text)", clips: [scoreClip(score), comment])
    }

    // MARK: - Fragen

    static func questionLine(_ question: Question) -> ModeratorLine {
        ModeratorLine(display: question.prompt, clips: [question.clip])
    }

    // MARK: - Referenz-Sätze für den Stimm-Klon (werden im Spiel nicht abgespielt)

    static let referenceClips = clips([
        "Hoi zäme! Ich bi de Moderator vom ABC. Jede Morge stell ich mine Gäscht Frage, und all Antworte fanged mit em gliiche Buechstabe aa.",
        "Wer zwölf Frage richtig beantwortet, hät gwunne. Das tönt eifach, aber mit em Timer im Nacke wird's grad chli hektisch!",
        "Hauptstadt vo Frankriich? Paris! Gröschte Kanton vo de Schwiiz? Graubünde! Super, wiiter so – no zwänzg Sekunde.",
    ], prefix: "ref", group: Group.reference)

    // MARK: - Bequemlichkeit (Systemzufall)

    static func pick(_ lines: [ModeratorLine]) -> ModeratorLine {
        lines.randomElement() ?? ModeratorLine("")
    }

    static func letterAnnouncement(_ letter: String) -> ModeratorLine {
        var rng = SystemRandomNumberGenerator()
        return letterAnnouncement(letter, using: &rng)
    }

    static func verdict(score: Int, target: Int) -> ModeratorLine {
        var rng = SystemRandomNumberGenerator()
        return verdict(score: score, target: target, using: &rng)
    }
}
