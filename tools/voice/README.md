# Eigene Stimme für den Moderator 🎙️

Der Moderator kann mit **deiner Stimme** sprechen. Dafür gibt es zwei Wege, die sich kombinieren lassen:

| | Was | Wo |
|---|---|---|
| **Selber einsprechen** | Begrüssung, Buchstaben, Countdown, Urteile, Zahlen – und auf Wunsch alle Fragen, in echter Mundart | App › Iistellige › Eigeni Stimm |
| **Stimm-Klon** | Alle ~580 Fragen werden aus ein paar Aufnahmen in deiner Stimme erzeugt | Mac, dieses Tool, lokales Modell |

Im Spiel gilt: **eigene Aufnahme → generierter Clip → iOS-Stimme** (was zuerst vorhanden ist).

### Bausteine statt ganzer Sätze (SBB-Prinzip)

Sätze mit Zahlen werden nicht mehr als ganze Sätze aufgenommen, sondern aus Bausteinen
zusammengesetzt – so wie die Durchsagen an Schweizer Bahnhöfen:

| Satz | Bausteine |
|---|---|
| «Du hesch 45 Sekunde.» | `rules-seconds-pre` «Du hesch …» + `zahl-45` «föifevierzg» + `rules-seconds-post` «… Sekunde.» |
| «Mit 12 richtige Antworte hesch gwunne.» | `rules-target-pre` + `zahl-12` + `rules-target-post` |
| «12 Pünkt.» | `zahl-12` + `score-points` «… Pünkt.» (bei 1: `score-one` «Ein Punkt.») |

Die Zahlen 0–30, 45, 60 und 90 gibt es je einmal, gesprochen **wie mitten im Satz** (Stimme oben
lassen). Statt 56 ganzen Sätzen sind es so 40 kurze Aufnahmen, und jede Kombination klingt gleich.
Die App schneidet beim Speichern Stille am Anfang und Ende weg, damit die Teile lückenlos aneinanderpassen.

Reihenfolge beim Abspielen: eigene Aufnahme des ganzen Satzes → **alle** Bausteine vorhanden →
generierter ganzer Satz → iOS-Stimme. Fehlt ein Baustein, wird nicht gemischt, sondern der ganze
Satz von der iOS-Stimme gelesen.

### Fragen ohne KI einsprechen

*Eigeni Stimm › Frage › Alli Frage am Stück*: Die App zeigt eine Frage nach der anderen gross an.
🎙️ antippen, Frage vorlesen, nochmals antippen – gespeichert, und es geht automatisch zur nächsten
Frage ohne Aufnahme. Rund 580 Sätze sind etwa 30–45 Minuten reine Sprechzeit; Fragen ohne Aufnahme
liest bis dahin die iOS-Stimme (oder ein generierter Clip). Der Stimm-Klon unten ist damit optional.

### Fragen aus einer langen Aufnahme zerlegen (z.B. ElevenLabs)

Wenn alle Fragen eines Buchstabens in einer Datei stecken (Reihenfolge wie in `fragen.txt`),
schneidet `split_fragen.py` sie in einzelne Clips – ganz ohne Spracherkennung: Es sucht die Pausen
und wählt die Schnitte so, dass jedes Stück zur Textlänge seiner Frage passt.

```bash
python3 tools/voice/split_fragen.py D aufnahme-d.mp3 --pruefen   # nur Zuordnung anzeigen
python3 tools/voice/split_fragen.py D aufnahme-d.mp3             # Clips schreiben
```

Für die Moderator-Sätze statt des Buchstabens die Nummer des Blocks aus
[`moderator-texte.md`](moderator-texte.md) angeben:

```bash
python3 tools/voice/split_fragen.py 4 aufnahme-buchstabe.mp3
```

Benötigt `numpy` und `ffmpeg`. Ein ⚠️ in der Liste markiert Stücke, deren Länge stark von der
Erwartung abweicht – dort kurz reinhören. Die Fragen für A, B und C und die Moderator-Blöcke 1–5
sind so entstanden.

## 1. In der App aufnehmen

1. *Iistellige › Moderator › Eigeni Stimm* öffnen.
2. Zuerst die drei **«Referenz für de Stimm-Klon»**-Sätze einsprechen (ruhig, deutlich, wie im Radio,
   in einem leisen Raum). Diese braucht das Modell, um deine Stimme zu lernen.
3. Wenn du magst, auch die Moderator-Sätze (Begrüessig, Buechstabe, Countdown, Urteil …). Diese hörst du
   sofort im Spiel – und sie werden auf dem Mac 1:1 übernommen, statt geklont.
4. Unten **«Ufnahme exportiere»** → per AirDrop an den Mac schicken.
5. Die Dateien in den Ordner `tools/voice/referenz/` legen (Dateinamen nicht ändern!).

> Du kannst die Referenz auch direkt am Mac aufnehmen (z.B. Sprachmemos, 10–30 s, beliebiger Text in
> deiner Mundart) und als `ref-1.m4a` in `tools/voice/referenz/` legen.

## 2. Mac einrichten (einmalig)

Voraussetzungen: Mac mit Apple Silicon (M1 oder neuer), Xcode, [Homebrew](https://brew.sh).

```bash
brew install uv
tools/voice/setup.sh            # Chatterbox Multilingual (Standard)
```

Beim ersten Erzeugen lädt das Modell ca. 3 GB von Hugging Face herunter. Danach läuft alles
**offline auf deinem Mac** – deine Stimme verlässt den Computer nicht.

## 3. Probehören

```bash
tools/voice/.venv-chatterbox/bin/python tools/voice/generate_clips.py --vorschau
open tools/voice/vorschau
```

Erzeugt 5 Moderator-Sätze und 10 Fragen zum Anhören. Klingt's noch nicht gut? Siehe *Feinschliff*.

## 4. Alle Clips erzeugen

```bash
tools/voice/.venv-chatterbox/bin/python tools/voice/generate_clips.py
```

- Schreibt `ABCSpiel/Resources/Clips/<schlüssel>.m4a` (z.B. `q-b-bern.m4a`).
- Dauert je nach Mac ca. 2–5 s pro Clip, also für alle ~700 Clips grob 30–60 Minuten.
- Abbrechen ist kein Problem: beim nächsten Start werden nur fehlende Clips erzeugt.
- Danach die App in Xcode neu bauen – die Clips sind automatisch dabei.

Nützliche Optionen:

```bash
--buchstabe A,B        # nur Fragen dieser Buchstaben (+ Moderator)
--nur-fragen           # nur Fragen
--nur-moderator        # nur Moderator-Sätze
--keys q-b-bern,letter-b --neu   # einzelne Clips neu erzeugen
--limit 20             # höchstens 20 Clips
--engine xtts          # anderes Modell (vorher: tools/voice/setup.sh xtts)
--engine say           # macOS-Systemstimme, nur um die Pipeline zu testen
--export-texte texte.md          # alle Sprechtexte als Liste
```

## Feinschliff

- **Bessere Referenz = besserer Klon.** 10–20 s, gleichmässig gesprochen, ohne Hall und Hintergrundgeräusche.
  Chatterbox nutzt die ersten ~10 s (die `ref-…`-Aufnahmen zuerst).
- **Aussprache:** Die Modelle haben vor allem Hochdeutsch gelernt. In `aussprache.txt` kannst du Wörter
  umschreiben (`Chäs = Chääs`). Danach betroffene Clips mit `--keys … --neu` neu erzeugen.
- **Tempo (XTTS):** `--speed 1.15` etwas schneller, wie im Radio.
- **Ausdruck/Tempo (Chatterbox):** `--exaggeration 0.7` lebhafter (Radio-Stil), `--cfg-weight 0.3` ruhiger/langsamer.
  Andere Variante eines Clips: `--seed 3 --keys … --neu`.
- **Einzelne schlechte Clips** einfach in der App selber einsprechen – eigene Aufnahmen haben Vorrang.

## Sicherheit der Python-Umgebungen prüfen

Die Modelle ziehen über 100 Python-Pakete nach. `audit_env.py` prüft eine Umgebung auf Hinweise für
Supply-Chain-Angriffe (Herkunft, entfernte/zurückgezogene Pakete, Malware-Meldungen, sehr frische Releases
mit/ohne PyPI-Herkunftsnachweis, unerklärte Pakete, Autostart-Dateien, veränderte Dateien, verdächtige
Code-Muster) und listet bekannte Sicherheitslücken:

```bash
tools/voice/.venv-chatterbox/bin/python -I tools/voice/audit_env.py chatterbox-tts soundfile numpy setuptools
tools/voice/.venv-xtts/bin/python -I tools/voice/audit_env.py coqui-tts torch torchaudio six soundfile numpy
```

Die Argumente sind die direkt installierten Pakete aus `setup.sh`. Am besten nach jeder (Neu-)Installation laufen lassen.

## Modelle

| Modell | Lizenz | Stärken |
|---|---|---|
| [Chatterbox Multilingual](https://github.com/resemble-ai/chatterbox) (Resemble AI) | MIT | Standard, gute Qualität, Deutsch, läuft auf Apple Silicon (MPS) |
| [XTTS-v2](https://huggingface.co/coqui/XTTS-v2) (Coqui) | Coqui Public Model License – **nur nicht-kommerziell** | nutzt mehrere Referenzen, läuft auf CPU (langsamer) |

Chatterbox versieht erzeugte Audios mit einem unhörbaren Wasserzeichen (Perth), das sie als KI-generiert kennzeichnet.

**Bitte nur die eigene Stimme klonen** – oder die von Personen, die ausdrücklich zugestimmt haben.
Die Referenz-Aufnahmen werden nicht ins Git eingecheckt (`.gitignore`).
