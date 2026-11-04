#!/usr/bin/env python3
"""Zerlegt eine Aufnahme aller Fragen eines Buchstabens in einzelne Clips.

Gedacht für Fragen, die am Stück eingesprochen oder extern erzeugt wurden (z.B. ElevenLabs):
eine Audiodatei pro Buchstabe, die Fragen in derselben Reihenfolge wie in fragen.txt.

    python3 tools/voice/split_fragen.py A aufnahme-a.mp3 [--pruefen]

Ohne Spracherkennung: Das Skript sucht die Pausen und wählt per dynamischer Programmierung
genau so viele Schnitte, dass die Länge jedes Stücks am besten zur Textlänge der Frage passt
und die Pausen möglichst lang sind. `--pruefen` zeigt nur die Zuordnung (Dauer vs. erwartet),
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
CLIPS = ROOT / "ABCSpiel/Resources/Clips"
SR = 16000
HOP = 160  # 10 ms
THRESHOLD_DB = -40


def slug(text: str) -> str:
    """Wie AnswerMatcher.normalize in Swift, Leerzeichen → Bindestrich."""
    s = text.lower().replace("ß", "ss")
    s = "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))
    return "-".join(re.sub(r"[\W_]", " ", s).split())


def questions(letter: str) -> list[tuple[str, str]]:
    result = []
    for line in FRAGEN.read_text(encoding="utf-8").splitlines():
        parts = [p.strip() for p in line.split("|")]
        if len(parts) >= 3 and parts[0] == letter:
            result.append((parts[1], parts[2]))
    return result


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
    parser.add_argument("buchstabe")
    parser.add_argument("audio", type=Path)
    parser.add_argument("--pruefen", action="store_true", help="nur Zuordnung anzeigen, nichts schreiben")
    parser.add_argument("--ziel", type=Path, default=CLIPS)
    args = parser.parse_args()

    letter = args.buchstabe.upper()
    qs = questions(letter)
    if not qs:
        sys.exit(f"Fehler: keine Fragen für {letter} in {FRAGEN}.")
    segments = align(loudness(args.audio), [q for q, _ in qs])
    rate = sum(e - s for s, e in segments) / sum(sum(c.isalnum() for c in q) for q, _ in qs)

    if not args.pruefen:
        args.ziel.mkdir(parents=True, exist_ok=True)
    for k, ((start, end), (prompt, answer)) in enumerate(zip(segments, qs)):
        expected = sum(c.isalnum() for c in prompt) * rate
        flag = "  ⚠️" if abs((end - start) - expected) > 0.35 * expected + 0.3 else ""
        key = f"q-{letter.lower()}-{slug(answer)}"
        print(f"{k + 1:3d} {start:7.2f}–{end:7.2f}  {end - start:4.2f}s (erw. {expected:4.2f}){flag}  {key}  {prompt}")
        if args.pruefen:
            continue
        # Etwas Luft lassen, aber nie bis in die Nachbarfrage.
        prev_end = segments[k - 1][1] if k else 0.0
        next_start = segments[k + 1][0] if k + 1 < len(segments) else end + 0.3
        a = max((prev_end + start) / 2 if k else 0.0, start - 0.08)
        b = min((end + next_start) / 2, end + 0.15)
        d = b - a
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{a:.3f}", "-t", f"{d:.3f}", "-i", str(args.audio),
                        "-af", f"afade=t=in:d=0.01,afade=t=out:st={d - 0.03:.3f}:d=0.03",
                        "-ac", "1", "-c:a", "aac", "-b:a", "64k", str(args.ziel / f"{key}.m4a")], check=True)
    if not args.pruefen:
        print(f"{len(qs)} Clips → {args.ziel}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
