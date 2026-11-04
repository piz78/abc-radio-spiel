# Konzept: Fragen und Clips vom Webserver

Ziel: `fragen.txt` und die Sprech-Clips liegen zusätzlich auf einem Webserver. Die App holt sich
dort neue oder geänderte Inhalte, **ohne neues App-Update** im App Store. Die App funktioniert
weiterhin offline mit dem, was sie mitbringt.

## Grundsätze

1. **Offline zuerst.** Das App-Bundle enthält immer einen vollständigen Grundstand
   (`fragen.txt` + `Resources/Clips`). Der Server liefert nur Aktualisierungen. Ohne Netz oder
   bei einem Fehler spielt die App mit dem letzten guten Stand weiter.
2. **Nur statische Dateien.** Kein eigenes Backend, keine Datenbank. Jeder Webserver mit HTTPS
   reicht (eigener Server/Webhosting, GitHub Pages, S3/R2, Netlify …).
3. **Ein Manifest beschreibt alles.** Die App lädt zuerst eine kleine `manifest.json` und
   entscheidet daraus, was fehlt. Unveränderte Clips werden nie zweimal geladen.
4. **Alles oder nichts.** Ein neuer Stand wird erst aktiv, wenn er vollständig geladen und
   geprüft ist. Nie mitten in einer Runde.
5. **Bestehende Reihenfolge bleibt.** Eigene Aufnahme → *heruntergeladener Clip* → mitgelieferter
   Clip → iOS-Stimme. Eigene Aufnahmen werden nie überschrieben.

## Aufbau auf dem Server

```
https://<server>/abc/v1/
  manifest.json                         ← das Einzige, was sich «in place» ändert
  fragen/fragen-3f9a1c2e.txt            ← Dateiname enthält Hash → unveränderlich
  clips/q-b-bern-8c1d04aa.m4a
  clips/greeting-2-51e0b7f3.m4a
  …
```

- `v1` ist die **Format-Version** (Aufbau des Manifests). Ändert sich das Format inkompatibel,
  kommt `v2` daneben; alte App-Versionen lesen weiter `v1`.
- Alle Dateien ausser `manifest.json` tragen die ersten 8 Zeichen ihres SHA-256 im Namen.
  Dadurch sind sie unveränderlich, dürfen lange gecacht werden
  (`Cache-Control: public, max-age=31536000, immutable`), und alte und neue Stände können
  gleichzeitig auf dem Server liegen.
- `manifest.json` bekommt `Cache-Control: no-cache` (die App fragt mit `If-None-Match` nach,
  der Server antwortet meist mit `304 Not Modified` – das kostet fast nichts).

Grösse heute: ~200 Clips ≈ 4 MB, bei allen ~1200 Fragen-Clips grob 25 MB. Das ist für einzelne
Dateien unproblematisch; ein Paket pro Buchstabe (ZIP) ist erst bei Bedarf nötig (siehe Ausbau).

## manifest.json

```json
{
  "format": 1,
  "contentVersion": 42,
  "published": "2026-11-04T18:30:00Z",
  "minAppBuild": 7,
  "fragen": {
    "path": "fragen/fragen-3f9a1c2e.txt",
    "sha256": "3f9a1c2e…",
    "bytes": 81234,
    "count": 1161
  },
  "clips": {
    "q-b-bern":   { "path": "clips/q-b-bern-8c1d04aa.m4a",   "sha256": "8c1d04aa…", "bytes": 18211, "text": "c0ffee12" },
    "greeting-2": { "path": "clips/greeting-2-51e0b7f3.m4a", "sha256": "51e0b7f3…", "bytes": 40211, "text": "9a7b3310" }
  }
}
```

| Feld | Bedeutung |
|---|---|
| `contentVersion` | Fortlaufende Nummer. Die App übernimmt nur einen **höheren** Stand. |
| `minAppBuild` | Ältere App-Builds ignorieren den Stand (z.B. wenn neue Clip-Bausteine Code brauchen). |
| `fragen.count` | Plausibilitätsprüfung nach dem Parsen. |
| `clips.<key>` | Schlüssel wie heute (`q-b-bern`, `letter-d`, `zahl-12` …), siehe `ClipCatalog`. |
| `clips.<key>.text` | Kurzer Hash des **gesprochenen Textes**. Erkennt veraltete Clips (siehe unten). |

Pfade sind relativ zum Ordner des Manifests. Clips, die im Manifest fehlen, gelten als «nicht
vom Server» – dann greift der mitgelieferte Clip oder die iOS-Stimme.

### Warum der Text-Hash wichtig ist

Der Clip-Schlüssel hängt nur an der **Antwort** (`q-b-bern`). Wird die **Frage** umformuliert,
bleibt der Schlüssel gleich – der alte Clip würde dann einen anderen Text vorlesen. Deshalb:

- Das Publizier-Skript berechnet für jeden Clip den Hash des aktuellen Textes aus
  `swift run abc-clips` und vergleicht ihn mit dem Text, aus dem der Clip erzeugt wurde
  (gespeichert in `clips-texte.json` neben den Clips). Passt er nicht, wird der Clip **nicht
  publiziert** und als «neu einsprechen» gemeldet.
- Die App vergleicht beim Abspielen den Text-Hash des Clips mit dem Text der aktuellen Frage.
  Passt er nicht, liest die iOS-Stimme. Das schützt auch mitgelieferte Clips und eigene
  Aufnahmen vor einem neuen Fragentext (eigene Aufnahmen bekommen dafür beim Speichern ein
  kleines Seitenfile `<key>.json` mit dem Text-Hash; in der Stimm-Ansicht als «veraltet» markiert).

## Ablauf in der App

### Wann

- Beim App-Start bzw. Wechsel in den Vordergrund, höchstens **einmal pro 6 Stunden**.
- Manuell: *Iistellige › Inhalt › «Jetzt aktualisieren»* (zeigt Stand, Datum, Anzahl Fragen/Clips).
- Optional nur über WLAN, falls der Download gross ist (Einstellung, Standard: immer – Clips sind klein).

### Schritte

```
1. GET manifest.json  (If-None-Match: <letztes ETag>)
   304 → fertig.
2. Prüfen: format == 1, contentVersion > aktiver Stand, minAppBuild <= eigener Build.
3. Fehlende Dateien bestimmen: alles, dessen sha256 lokal noch nicht vorhanden ist.
4. Laden nach  Application Support/Inhalt/staging/  (URLSession, max. 4 parallel).
   Jede Datei: Grösse und SHA-256 prüfen, sonst verwerfen.
5. fragen.txt mit QuestionBank parsen und prüfen:
   - Anzahl == fragen.count, mindestens so viele spielbare Buchstaben wie im Bundle,
   - jede Antwort beginnt mit ihrem Buchstaben (gleiche Regeln wie validate_questions.py).
6. Aktivieren: neues index.json schreiben (Schlüssel → lokaler Dateiname) und atomar
   ersetzen (write to temp + rename). Danach gilt der neue Stand.
7. Aufräumen: Dateien, die in keinem Index mehr stehen, löschen.
```

Bricht etwas ab (kein Netz, App beendet), bleibt `staging/` liegen; beim nächsten Versuch werden
bereits geprüfte Dateien wiederverwendet. Weil die Dateien nach Hash benannt sind, gibt es keine
halben Zustände.

### Lokale Ablage

```
Application Support/Inhalt/
  index.json          { "contentVersion": 42, "etag": "...", "fragen": "fragen-3f9a1c2e.txt",
                        "clips": { "q-b-bern": { "file": "q-b-bern-8c1d04aa.m4a", "text": "c0ffee12" } } }
  files/              alle geladenen Dateien (Hash-Namen)
  staging/
```

`Application Support` statt `Caches`, damit iOS die Dateien nicht bei Speichermangel löscht;
mit `isExcludedFromBackup`, weil sie jederzeit neu ladbar sind.

### Anpassungen im Code

| Wo | Änderung |
|---|---|
| neu `Services/ContentUpdater.swift` | Manifest holen, Diff, Download, Prüfung, Aktivierung (Schritte oben). `@MainActor`-Status für die Einstellungen (`idle / prüft / lädt 37/120 / aktuell / Fehler`). |
| neu `Core/ContentManifest.swift` | `Codable`-Typen für Manifest und Index, Diff-Funktion – ohne UI, damit testbar mit `swift test`. |
| `App/AppModel.swift` | `bank` wird `private(set) var`. Beim Start: heruntergeladene `fragen.txt` falls gültig, sonst Bundle. Neuer Stand wird bei **nächster Karte** übernommen, nie während einer Runde. |
| `Services/ClipLibrary.swift` | Zwischen `recordingURL` und `bundledURL` eine Stufe `downloadedURL(for:)` aus `index.json`; Text-Hash-Prüfung in `url(for:)` / `playlist(for:)`. `bundledCount` → `availableCount`. |
| `App/AppSettings.swift` | `contentBaseURL` (Standard fest im Code, in einem versteckten Entwickler-Menü änderbar, z.B. für einen Test-Server), `lastContentCheck`. |
| `Views/SettingsView.swift` | Abschnitt «Inhalt»: Stand, «Jetzt aktualisieren», «Auf mitgelieferten Stand zurücksetzen». |
| `Info.plist` | nichts nötig, solange der Server HTTPS mit gültigem Zertifikat hat (ATS). |

Statistik und «zuletzt gespielte Buchstaben» hängen nicht an Fragen-IDs; die zeilenbasierten
IDs (`B-12`) dürfen sich also bei einem neuen Stand ändern.

## Publizieren

Neues Skript `tools/publish/build_content.py`:

```bash
python3 tools/publish/build_content.py              # baut dist/abc/v1/ und prüft alles
python3 tools/publish/build_content.py --hochladen  # baut und lädt hoch
```

1. `tools/validate_questions.py` ausführen – bei Fehlern Abbruch.
2. Manifest aller Clips via `swift run abc-clips` holen (gleiche Quelle wie App und Generator).
3. Für jeden Clip in `ABCSpiel/Resources/Clips/`: SHA-256 berechnen, Text-Hash prüfen
   (veraltete Clips auslassen und auflisten), nach `dist/abc/v1/clips/<key>-<hash8>.m4a` kopieren.
4. `fragen.txt` nach `dist/abc/v1/fragen/fragen-<hash8>.txt`.
5. `contentVersion` = bisherige Version auf dem Server + 1 (vorher `manifest.json` laden).
6. **Hochladen in der richtigen Reihenfolge:** zuerst alle neuen Dateien, **zuletzt**
   `manifest.json`. So sieht eine App nie ein Manifest, dessen Dateien noch fehlen.
   Alte Dateien erst nach ein paar Tagen löschen (Apps, die gerade laden).

Hochladen je nach Server:

- **Eigener Server / Webhosting:**
  `rsync -av --ignore-existing dist/abc/v1/{fragen,clips} user@server:/var/www/abc/v1/`
  und danach `manifest.json` separat (oder SFTP/`lftp mirror`).
- **GitHub Pages / S3 / R2:** dasselbe über die jeweilige CLI.

### Automatisch per GitHub Actions (empfohlen)

Neuer Workflow `.github/workflows/content.yml`: Bei jedem Push auf `main`, der `fragen.txt` oder
`Resources/Clips/` ändert, laufen die vorhandenen Prüfungen (`validate_questions.py`, `swift test`),
danach `build_content.py --hochladen`. Zugangsdaten (SSH-Key bzw. Token) als Repository-Secret.
Damit gilt: **Frage in `fragen.txt` ändern oder Clip committen → mergen → Apps haben es beim
nächsten Start.** Dasselbe Repo bleibt die einzige Quelle; der Server ist nur eine Kopie.

## Sicherheit

- **Nur HTTPS** (ATS erzwingt das ohnehin).
- **SHA-256 jeder Datei** wird geprüft; Grössen-Obergrenzen (Manifest 1 MB, Fragen 2 MB,
  Clip 1 MB, gesamt 100 MB).
- **Clip-Schlüssel** nur aus `[a-z0-9-]`, Pfade ohne `..` – verhindert, dass ein manipuliertes
  Manifest Dateien ausserhalb von `Inhalt/` schreibt.
- **Fragen werden nur als Daten gelesen**, nie ausgeführt; Clips nur abgespielt.
  Das ist auch im Sinne der App-Store-Richtlinien (Inhalte nachladen ja, Code nachladen nein).
- **Signatur (Ausbaustufe):** Manifest mit Ed25519 signieren (`manifest.json.sig`), öffentlicher
  Schlüssel fest in der App, Prüfung mit `CryptoKit`. Sinnvoll, sobald der Server nicht allein
  in deiner Hand ist; da das Manifest alle Hashes enthält, sind damit auch alle Dateien geschützt.

## Umsetzung in Etappen

| Etappe | Inhalt | Aufwand |
|---|---|---|
| **1. Fragen** | Manifest nur mit `fragen`, `ContentUpdater`, `AppModel` lädt neue Fragen, Abschnitt in Einstellungen, `build_content.py` ohne Clips. Bereits nützlich: Fragen korrigieren ohne App-Update. | klein |
| **2. Clips** | Clips im Manifest, Download mit Diff, Stufe in `ClipLibrary`, Text-Hash-Prüfung, Aufräumen. | mittel |
| **3. Automatisch** | GitHub-Actions-Workflow zum Publizieren. | klein |
| **4. Ausbau** | Signatur; Clips pro Buchstabe als ZIP (falls viele kleine Requests stören); Hintergrund-Aktualisierung (`BGAppRefreshTask`); Rückmeldung «Frage falsch?» per Mail-Link. | nach Bedarf |

### Tests

- `swift test`: Manifest-Decoding, Diff (neu / geändert / gelöscht), Ablehnung bei
  `contentVersion` ≤ aktiv, `minAppBuild`, ungültigen Schlüsseln, falschem Hash, Fragen-Prüfung.
- CI: `build_content.py` ohne Hochladen laufen lassen und das erzeugte Manifest prüfen
  (wie heute schon das Clip-Manifest).
- Manuell: lokaler Test-Server (`python3 -m http.server` im `dist/`-Ordner, im Simulator über
  das Entwickler-Menü als `contentBaseURL` eintragen), Flugmodus, Abbruch mitten im Download.

## Offene Entscheide

1. **Welcher Server?** Eigenes Webhosting, GitHub Pages oder ein Objektspeicher. Das Konzept
   funktioniert mit allen; davon hängt nur der Upload-Schritt ab.
2. **Wie viele Clips bleiben im App-Bundle?** Vorschlag: Moderator-Clips und Zahlen immer
   mitliefern (klein, ohne sie klingt das Spiel falsch), Fragen-Clips können mit der Zeit nur
   noch vom Server kommen – das hält die App klein.
3. **Öffentliche URL?** Die Dateien sind ohne Login abrufbar. Falls die Clips nicht frei
   zugänglich sein sollen, braucht es einen einfachen Token im Header (schützt aber nur schwach,
   da er in der App steckt).
