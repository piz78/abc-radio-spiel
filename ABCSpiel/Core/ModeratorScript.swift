import Foundation

/// Ein Satz des Moderators: Anzeigetext und (leicht angepasster) Text für die Sprachausgabe.
struct ModeratorLine: Equatable, Sendable {
    let display: String
    let spoken: String

    init(_ display: String, spoken: String? = nil) {
        self.display = display
        self.spoken = spoken ?? display
    }
}

/// Alles, was der Moderator «Ruedi» sagt – in Schweizerdeutsch.
enum ModeratorScript {
    static let moderatorName = "Ruedi"

    /// Aussprache der Buchstaben für die Sprachausgabe.
    static let letterNames: [String: String] = [
        "A": "A", "B": "Be", "C": "Ze", "D": "De", "E": "E", "F": "Eff", "G": "Ge",
        "H": "Ha", "I": "I", "J": "Jott", "K": "Ka", "L": "Ell", "M": "Emm", "N": "Enn",
        "O": "O", "P": "Pe", "Q": "Ku", "R": "Err", "S": "Ess", "T": "Te", "U": "U",
        "V": "Fau", "W": "We", "X": "Ix", "Y": "Üpsilon", "Z": "Zett",
    ]

    /// «B wie Bärn» – Schweizer Buchstabier-Beispiele.
    static let letterExamples: [String: String] = [
        "A": "Aarau", "B": "Bärn", "C": "Chur", "D": "Davos", "E": "Emme", "F": "Fribourg",
        "G": "Glarus", "H": "Herisau", "I": "Interlake", "J": "Jura", "K": "Kreuzlinge",
        "L": "Luzärn", "M": "Murte", "N": "Nöieburg", "O": "Olte", "P": "Pilatus", "Q": "Quinte",
        "R": "Rhy", "S": "Säntis", "T": "Thun", "U": "Uri", "V": "Vevey", "W": "Winterthur",
        "X": "Xylophon", "Y": "Yverdon", "Z": "Zug",
    ]

    static func spokenLetter(_ letter: String) -> String {
        letterNames[letter.uppercased()] ?? letter
    }

    // MARK: - Begrüssung

    static let greetings: [ModeratorLine] = [
        ModeratorLine("Hoi zäme und härzlich willkomme bim ABC!"),
        ModeratorLine("Grüezi mitenand – es isch Ziit für s'ABC!"),
        ModeratorLine("Sali! Schön, bisch wieder debii bim ABC."),
        ModeratorLine("Guete Morge! Bisch parat für e Rundi ABC?"),
        ModeratorLine("Hallo, da isch de \(moderatorName) – und das isch s'ABC!"),
    ]

    static func rules(seconds: Int, target: Int) -> ModeratorLine {
        ModeratorLine(
            "Ich stell dir Frage – und all Antworte fanged mit em gliiche Buechstabe aa. " +
            "Du hesch \(seconds) Sekunde. Mit \(target) richtige Antworte hesch gwunne. " +
            "Wenn d'öppis nid weisch, säg eifach «wiiter»."
        )
    }

    static func letterAnnouncement<R: RandomNumberGenerator>(_ letter: String, using rng: inout R) -> ModeratorLine {
        let l = letter.uppercased()
        let spoken = spokenLetter(l)
        let example = letterExamples[l] ?? l
        let variants: [ModeratorLine] = [
            ModeratorLine("Din Buechstabe isch: \(l) – wie \(example)!",
                          spoken: "Din Buechstabe isch: \(spoken). \(spoken) wie \(example)!"),
            ModeratorLine("Hüt spilsch mit em \(l) – \(l) wie \(example)!",
                          spoken: "Hüt spilsch mit em \(spoken). \(spoken) wie \(example)!"),
            ModeratorLine("Und de Buechstabe isch … \(l)! \(l) wie \(example).",
                          spoken: "Und de Buechstabe isch: \(spoken)! \(spoken) wie \(example)."),
        ]
        return variants.randomElement(using: &rng)!
    }

    // MARK: - Countdown

    static let countdown: [ModeratorLine] = [
        ModeratorLine("Achtung …"),
        ModeratorLine("fertig …"),
        ModeratorLine("los!"),
    ]

    // MARK: - Schluss

    static let timeUp: [ModeratorLine] = [
        ModeratorLine("Und Stopp – d'Ziit isch um!"),
        ModeratorLine("Piiip – fertig!"),
        ModeratorLine("Stopp! Das wärs gsi."),
    ]

    static let outOfQuestions = ModeratorLine("Wow – mir sind d'Frage usgange!")

    static func verdict<R: RandomNumberGenerator>(score: Int, target: Int, using rng: inout R) -> ModeratorLine {
        let points = score == 1 ? "1 Punkt" : "\(score) Pünkt"
        let options: [String]
        switch score {
        case ..<(target / 3):
            options = [
                "\(points). Hoppla – das isch hüt nid din Buechstabe gsi. Nomal probiere!",
                "\(points). Gäll, da hets di chli verwütscht. Grad nomal!",
            ]
        case ..<(target * 2 / 3):
            options = [
                "\(points) – nid schlächt, aber da liit no meh drin!",
                "\(points). Es guets Fundament – s'nächscht Mal gits meh!",
            ]
        case ..<target:
            options = [
                "\(points)! Knapp verbii – \(target) wäred s'Ziel gsi. So nöch!",
                "\(points) – oh nei, es hät ganz knapp nid glanget!",
            ]
        case ..<(target + 5):
            options = [
                "\(points) – gwunne! Gratuliere, du hesch s'ABC gschafft!",
                "\(points)! Bravo, das isch e Siig. Du chasch stolz sii!",
            ]
        default:
            options = [
                "Wahnsinn, \(points)! Du bisch e richtigi ABC-Legände!",
                "\(points)!! Sone Resultat gits nid all Tag – Huet ab!",
            ]
        }
        return ModeratorLine(options.randomElement(using: &rng)!)
    }

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
