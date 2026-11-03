# ABC – s'Radiospiel für dihei 📻

Eine iOS-App (SwiftUI) nach dem Vorbild des Kult-Radiospiels «ABC» auf Radio SRF 3:
**Ein Buchstabe, 45 Sekunden, mindestens zwölf richtige Antworten.**
Fan-Projekt, nicht offiziell.

## Features

- 🃏 **Generierte Karten** – 581 Fragen in Mundart für 23 Buchstaben; jede Runde zieht eine
  neue Karte (zuletzt gespielte Buchstaben werden vermieden, Fragen werden gemischt).
- ⏱️ **Timer** – 45 s (einstellbar), Ring-Anzeige, Ticken in den letzten 5 Sekunden, Buzzer.
- 🎙️ **Moderator «Ruedi»** – begrüsst, zieht den Buchstaben («B wie Bärn!»), zählt
  «Achtung … fertig … los!», stellt die Fragen und gibt am Schluss sein Urteil ab – auf
  Schweizerdeutsch, per Sprachausgabe.
- ✅ **Antworten** – per Knopf («Richtig» / «Wiiter») oder optional per **Spracherkennung**:
  die App hört zu, erkennt die richtige Antwort (unscharfer Vergleich) und «wiiter» zum Passen.
- 📊 **Resultat & Statistik** – alle Fragen mit Lösungen, Korrektur per Antippen,
  Rekord, Siege, Durchschnitt.
- 👥 **Mit Fründe spiele** – du moderierst, die Lösungen werden dir angezeigt.
- 🗂️ **Chartestapel** – Karten für jeden Buchstaben generieren, anschauen und teilen.
- 🗣️ **Eigene Stimme** – Moderator-Sätze in der App selber einsprechen, und mit einem lokalen
  KI-Modell auf dem Mac alle Fragen in deiner Stimme erzeugen → [tools/voice/README.md](tools/voice/README.md).

## Starten

1. Mac mit **Xcode 16** oder neuer.
2. `ABCSpiel.xcodeproj` öffnen.
3. Unter *Signing & Capabilities* dein Team wählen und ggf. die Bundle-ID
   (`com.example.ABCSpiel`) anpassen.
4. iPhone oder Simulator wählen → ▶︎ Run.

Mindestversion: iOS 17.

### Tipp für die Stimme

iOS hat keine echte Schweizerdeutsch-Stimme; die App nimmt eine Schweizer (de-CH) Stimme,
falls vorhanden, sonst eine deutsche. Viel besser klingen die *verbesserten/Premium*-Stimmen:
iPhone-Einstellungen › Bedienungshilfen › Gesprochene Inhalte › Stimmen › Deutsch.
In der App unter *Iistellige › Moderator* auswählen.

## Projektstruktur

```
ABCSpiel/
  App/         Einstieg, AppModel, Einstellungen
  Core/        Spiellogik ohne UI (Karten, Runde, Antwortvergleich, Moderator-Texte, Statistik)
  Services/    Sprachausgabe, Spracherkennung, Audio-Session, Töne
  Views/       SwiftUI-Screens
  Resources/   fragen.txt – die Fragen-Datenbank, Clips/ – generierte Sprach-Clips
Tests/         Unit-Tests der Core-Logik (swift test)
tools/         validate_questions.py – prüft die Fragen-Datenbank
tools/voice/   Stimm-Klon auf dem Mac (generate_clips.py, setup.sh)
tools/clip-manifest/  `swift run abc-clips` – Liste aller Sprech-Clips
```

## Fragen ergänzen

`ABCSpiel/Resources/fragen.txt`, eine Frage pro Zeile:

```
B | Bundesstadt vo de Schwiiz? | Bern | Bärn
```

Buchstabe | Frage | Antwort | Alternativen (mit `;` getrennt). Danach prüfen:

```
python3 tools/validate_questions.py
swift test
```

Siehe auch [PLAN.md](PLAN.md) für das Konzept.
