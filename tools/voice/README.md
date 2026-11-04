# Eigene Stimme für den Moderator 🎙️

Der Moderator kann mit **deiner Stimme** sprechen. Dafür gibt es zwei Wege, die sich kombinieren lassen:

| | Was | Wo |
|---|---|---|
| **Selber einsprechen** | Begrüssung, Buchstaben, Countdown, Urteile … in echter Mundart | App › Iistellige › Eigeni Stimm |
| **Stimm-Klon** | Alle ~580 Fragen werden aus ein paar Aufnahmen in deiner Stimme erzeugt | Mac, dieses Tool, lokales Modell |

Im Spiel gilt: **eigene Aufnahme → generierter Clip → iOS-Stimme** (was zuerst vorhanden ist).

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
