#!/usr/bin/env python3
"""Zerlegt eine Aufnahme aller Fragen eines Buchstabens in einzelne Clips.

Gedacht für Fragen, die am Stück eingesprochen oder extern erzeugt wurden (z.B. ElevenLabs):
eine Audiodatei pro Buchstabe, die Fragen in derselben Reihenfolge wie in fragen.txt.

    python3 tools/voice/split_fragen.py A aufnahme-a.mp3 [--pruefen]
    python3 tools/voice/split_fragen.py 4 aufnahme-block-4.mp3     # Block 4 aus moderator-texte.md

Ohne Spracherkennung: Das Skript sucht die Pausen und wählt per dynamischer Programmierung
genau so viele Schnitte, dass die Länge jedes Stücks am besten zur Textlänge der Frage passt
und die Pausen möglichst lang sind. Statt eines Buchstabens geht auch die Nummer eines Blocks
aus tools/voice/moderator-texte.md (Moderator-Sätze, Schlüssel aus der Zeile «Schlüssel:»). `--pruefen` zeigt nur die Zuordnung (Dauer vs. erwartet),
ohne Dateien zu schreiben. Ergebnis: ABCSpiel/Resources/Clips/q-<buchstabe>-<antwort>.m4a.

Benötigt: numpy, ffmpeg.
"""
from __future__ import annotations

import argparse
import math
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
FRAGEN = ROOT / "ABCSpiel/Resources/fragen.txt"
MODERATOR = ROOT / "tools/voice/moderator-texte.md"
CLIPS = ROOT / "ABCSpiel/Resources/Clips"
SR = 16000
HOP = 160  # 10 ms
THRESHOLD_DB = -40  # darunter zählt es als Pause
SILENCE_DB = -55  # darunter ist es wirklich still (für die Clip-Ränder)


def slug(text: str) -> str:
    """Wie AnswerMatcher.normalize in Swift, Leerzeichen → Bindestrich."""
    s = text.lower().replace("ß", "ss")
    s = "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))
    return "-".join(re.sub(r"[\W_]", " ", s).split())


def questions(letter: str) -> list[tuple[str, str]]:
    """(Text, Clip-Schlüssel) der Fragen eines Buchstabens."""
    result = []
    for line in FRAGEN.read_text(encoding="utf-8").splitlines():
        parts = [p.strip() for p in line.split("|")]
        if len(parts) >= 3 and parts[0] == letter:
            result.append((parts[1], f"q-{letter.lower()}-{slug(parts[2])}"))
    return result


def moderator_block(number: int) -> list[tuple[str, str]]:
    """(Text, Clip-Schlüssel) eines Blocks aus moderator-texte.md."""
    text = MODERATOR.read_text(encoding="utf-8")
    match = re.search(rf"^## {number}\. .*?^```\n(.*?)^```\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not match:
        sys.exit(f"Fehler: Block {number} nicht in {MODERATOR}.")
    lines = [line.strip() for line in match.group(1).splitlines() if line.strip()]
    keys_text = match.group(2).split("Schlüssel:", 1)[-1].split("\n\n")[0]
    keys = re.findall(r"[a-z]+(?:-[a-z0-9]+)*", keys_text)
    if len(keys) != len(lines):
        sys.exit(f"Fehler: Block {number} hat {len(lines)} Zeilen, aber {len(keys)} Schlüssel.")
    return list(zip(lines, keys))


def loudness(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
                         check=True, capture_output=True).stdout
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768
    frames = len(x) // HOP
    rms = np.sqrt((x[: frames * HOP].reshape(frames, HOP) ** 2).mean(1) + 1e-12)
    return 20 * np.log10(rms)


def quiet_runs(db: np.ndarray) -> list[tuple[int, int]]:
    runs, start = [], None
    for i, quiet in enumerate(db < THRESHOLD_DB):
        if quiet and start is None:
            start = i
        elif not quiet and start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(db)))
    return runs


def align(db: np.ndarray, texts: list[str]) -> list[tuple[float, float]]:
    """Gibt (start, ende) in Sekunden für jede Frage zurück."""
    n, frames = len(texts), len(db)
    runs = quiet_runs(db)
    begin = runs[0][1] if runs and runs[0][0] == 0 else 0
    end = runs[-1][0] if runs and runs[-1][1] == frames else frames
    gaps = [(a, b) for a, b in runs if a > begin and b < end]
    if len(gaps) < n - 1:
        sys.exit(f"Fehler: nur {len(gaps)} Pausen gefunden, {n - 1} nötig.")
    chars = [sum(c.isalnum() for c in t) for t in texts]
    rate = ((end - begin) * 0.01 - 0.3 * (n - 1)) / sum(chars)  # Sekunden pro Buchstabe

    points = [(begin, begin)] + gaps + [(end, end)]  # (Pause-Anfang, Pause-Ende)
    m = len(points)
    cost = np.full((n + 1, m), math.inf)
    back = np.zeros((n + 1, m), dtype=int)
    cost[0][0] = 0
    for k in range(1, n + 1):
        expected = chars[k - 1] * rate
        sigma = 0.2 * expected + 0.15
        for j in range(1, m):
            if (k == n) != (j == m - 1):
                continue
            bonus = 0 if k == n else -4 * math.log((points[j][1] - points[j][0]) * 0.01 / 0.3)
            for i in range(j):
                if cost[k - 1][i] == math.inf:
                    continue
                dur = (points[j][0] - points[i][1]) * 0.01
                value = cost[k - 1][i] + ((dur - expected) / sigma) ** 2 + bonus
                if value < cost[k][j]:
                    cost[k][j], back[k][j] = value, i
    segments, j = [], m - 1
    for k in range(n, 0, -1):
        i = back[k][j]
        segments.append((points[i][1] * 0.01, points[j][0] * 0.01))
        j = i
    return segments[::-1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("buchstabe", help="Buchstabe (Fragen) oder Nummer eines Blocks in moderator-texte.md")
    parser.add_argument("audio", type=Path)
    parser.add_argument("--pruefen", action="store_true", help="nur Zuordnung anzeigen, nichts schreiben")
    parser.add_argument("--ziel", type=Path, default=CLIPS)
    args = parser.parse_args()

    if args.buchstabe.isdigit():
        qs = moderator_block(int(args.buchstabe))
    else:
        qs = questions(args.buchstabe.upper())
    if not qs:
        sys.exit(f"Fehler: keine Fragen für {args.buchstabe} in {FRAGEN}.")
    db = loudness(args.audio)
    segments = align(db, [q for q, _ in qs])
    rate = sum(e - s for s, e in segments) / sum(sum(c.isalnum() for c in q) for q, _ in qs)

    if not args.pruefen:
        args.ziel.mkdir(parents=True, exist_ok=True)
    for k, ((start, end), (prompt, key)) in enumerate(zip(segments, qs)):
        expected = sum(c.isalnum() for c in prompt) * rate
        flag = "  ⚠️" if abs((end - start) - expected) > 0.35 * expected + 0.3 else ""
        print(f"{k + 1:3d} {start:7.2f}–{end:7.2f}  {end - start:4.2f}s (erw. {expected:4.2f}){flag}  {key}  {prompt}")
        if args.pruefen:
            continue
        # Bis zur echten Stille ausdehnen (leise Endsilben!) plus etwas Luft,
        # aber nie über die Mitte der Pause zur Nachbarfrage hinaus.
        lo = (segments[k - 1][1] + start) / 2 if k else 0.0
        hi = (end + segments[k + 1][0]) / 2 if k + 1 < len(segments) else len(db) * 0.01
        f = int(round(start * 100))
        while f > lo * 100 and db[f - 1] > SILENCE_DB:
            f -= 1
        a = max(lo, f * 0.01 - 0.05)
        f = int(round(end * 100))
        while f < hi * 100 - 1 and db[f] > SILENCE_DB:
            f += 1
        b = min(hi, f * 0.01 + 0.08)
        d = b - a
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{a:.3f}", "-t", f"{d:.3f}", "-i", str(args.audio),
                        "-af", f"afade=t=in:d=0.01,afade=t=out:st={d - 0.03:.3f}:d=0.03",
                        "-ac", "1", "-c:a", "aac", "-b:a", "64k", str(args.ziel / f"{key}.m4a")], check=True)
    if not args.pruefen:
        print(f"{len(qs)} Clips → {args.ziel}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
