#!/usr/bin/env python3
"""Prüft ABCSpiel/Resources/fragen.txt: Format, Anfangsbuchstabe, Duplikate, Anzahl pro Buchstabe."""
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

PATH = Path(__file__).resolve().parent.parent / "ABCSpiel" / "Resources" / "fragen.txt"
MIN_PER_LETTER = 20
PASS_WORDS = {"weiter", "wiiter", "passe", "pass"}


def fold(s: str) -> str:
    s = s.replace("ß", "ss")
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn").lower()


def main() -> int:
    errors = []
    per_letter = defaultdict(list)
    for no, raw in enumerate(PATH.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 3 or not all(parts[:3]):
            errors.append(f"Zeile {no}: Format ungültig: {raw}")
            continue
        letter, prompt, answer = parts[0].upper(), parts[1], parts[2]
        if len(letter) != 1:
            errors.append(f"Zeile {no}: Buchstabe ungültig: {letter}")
        if fold(answer)[0].upper() != letter:
            errors.append(f"Zeile {no}: Antwort «{answer}» beginnt nicht mit {letter}")
        words = set(fold(prompt).replace("?", " ").replace(",", " ").split())
        if words & PASS_WORDS:
            errors.append(f"Zeile {no}: Frage enthält ein Pass-Wort: {prompt}")
        per_letter[letter].append((no, prompt, answer))

    for letter, items in sorted(per_letter.items()):
        dup_a = [a for a, c in Counter(fold(a) for _, _, a in items).items() if c > 1]
        dup_p = [p for p, c in Counter(fold(p) for _, p, _ in items).items() if c > 1]
        if dup_a:
            errors.append(f"{letter}: doppelte Antworten: {dup_a}")
        if dup_p:
            errors.append(f"{letter}: doppelte Fragen: {dup_p}")
        if len(items) < MIN_PER_LETTER:
            errors.append(f"{letter}: nur {len(items)} Fragen (min. {MIN_PER_LETTER})")

    total = sum(len(v) for v in per_letter.values())
    print(f"{total} Fragen, {len(per_letter)} Buchstaben")
    print("  ".join(f"{l}:{len(v)}" for l, v in sorted(per_letter.items())))
    for e in errors:
        print("FEHLER:", e)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
