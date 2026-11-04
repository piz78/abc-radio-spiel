# Plan: «ABC» – s'Radiospiel als iOS-App

Inspiriert vom Kult-Radiospiel «ABC» auf Radio SRF 3:
**Ein Buchstabe, 45 Sekunden, mindestens zwölf richtige Antworten.**
Ein Moderator stellt Frage um Frage – jede Antwort beginnt mit dem gezogenen Buchstaben.
Wer nicht weiss, sagt «wiiter» (passen).

## Ziele

1. **Generierte Karten** – aus einer Fragen-Datenbank (~600 Fragen, 23 Buchstaben) wird
   pro Runde eine Karte gezogen: zufälliger Buchstabe (zuletzt gespielte werden vermieden),
   25 gemischte Fragen.
2. **Timer** – 45 s (einstellbar 30/45/60/90), Ring-Anzeige, Ticken in den letzten 5 Sekunden,
   Buzzer am Schluss.
3. **Moderatorin «Vreni»** – spricht Begrüssung, Buchstaben, Countdown («Achtung, fertig, los!»),
   die Fragen und das Schlussurteil. Texte in **Schweizerdeutsch**, Sprachausgabe via
   `AVSpeechSynthesizer` (Schweizer Stimme falls vorhanden, sonst Deutsch; wählbar).
4. **Antworten**
   - Knöpfe «Richtig ✓» / «Wiiter →» (Selbstbewertung, Lösung blitzt kurz auf).
   - Optional **Spracherkennung** (`SFSpeechRecognizer`, de-CH): richtige Antwort wird
     automatisch erkannt (unscharfer Vergleich), «wiiter»/«passe» überspringt.
5. **Resultat** – Punkte, Urteil des Moderators, Liste aller Fragen mit Lösungen;
   Antippen korrigiert die Wertung. Statistik (Spiele, Rekord, Siege).
6. **Mit Fründe spiele** – du bist der Moderator: Lösungen werden während dem Spiel angezeigt.
7. **Kartenstapel** – Karten generieren, anschauen und teilen (zum Vorlesen/Ausdrucken).

## Architektur

```
ABCSpiel/
  App/        ABCSpielApp (Einstieg), AppSettings, StatsStore
  Core/       Plattformunabhängige Logik (auch als Swift-Package testbar)
              Question, QuestionBank (Parser), CardGenerator, GameRound,
              AnswerMatcher (Normalisierung + Levenshtein), ModeratorScript (Mundart),
              GameStats, SeededGenerator
  Services/   ModeratorVoice (TTS), AnswerListener (Spracherkennung),
              AudioSession, SoundFX (Töne + Haptik)
  Views/      HomeView, GameView (+ GameController), CardRevealView, TimerRing,
              ModeratorBubble, ResultView, CardDeckView, SettingsView, Theme
  Resources/  fragen.txt  (Format: `Buchstabe | Frage | Antwort | Alternativen;…`)
Tests/ABCCoreTests  XCTest für die Core-Logik und die Fragen-Datenbank
Package.swift       Swift-Package «ABCCore» (zeigt auf ABCSpiel/Core) für `swift test`
ABCSpiel.xcodeproj  Xcode-16-Projekt mit synchronisiertem Ordner (keine Dateiliste nötig)
tools/validate_questions.py  Prüft die Datenbank (Anfangsbuchstabe, Duplikate, Anzahl)
.github/workflows/ios.yml    CI: `swift test` + App-Build für den iOS-Simulator
```

- SwiftUI, iOS 17+, `@Observable`.
- Spielablauf als Zustandsmaschine im `GameController`:
  `intro → countdown → playing → finished`.
- `GameRound` ist ein reiner Wert-Typ mit injizierter Zeit → deterministisch testbar.

## Umsetzungsschritte

1. Projektgerüst (Xcode-Projekt, Package.swift, CI-Workflow)
2. Core-Logik + Unit-Tests
3. Fragen-Datenbank in Mundart + Validierungsskript
4. Services: Sprachausgabe, Spracherkennung, Audio-Session, Sounds
5. Views + Spielablauf
6. App-Icon, README
7. Build & Tests via GitHub Actions (macOS-Runner)
