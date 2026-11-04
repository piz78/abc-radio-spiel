#!/usr/bin/env python3
"""
Prüft eine Python-Umgebung (venv) auf Hinweise für Supply-Chain-Angriffe.

Aufruf mit dem Python der zu prüfenden Umgebung:
  tools/voice/.venv-chatterbox/bin/python tools/voice/audit_env.py chatterbox-tts
  tools/voice/.venv-xtts/bin/python       tools/voice/audit_env.py coqui-tts torch torchaudio six

Die Argumente sind die direkt installierten Pakete (wie in setup.sh); daraus wird geprüft,
ob jedes installierte Paket über den Abhängigkeitsbaum erklärbar ist.

Prüfungen:
  1. Herkunft      – alles von PyPI? (keine Git-/URL-/lokalen Installationen)
  2. PyPI-Abgleich – existiert Paket/Version noch? zurückgezogen (yanked)? bekannte Lücken/Malware?
  3. Frische       – sehr neue Pakete oder Versionen (typisches Zeitfenster für kompromittierte Releases)
  4. Herleitung    – Pakete, die keine der installierten Abhängigkeiten verlangt (Typosquatting-Verdacht)
  5. Auto-Start    – .pth-Dateien mit Code, sitecustomize/usercustomize
  6. Integrität    – stimmen die Dateien mit den Prüfsummen aus RECORD überein?
  7. Code-Muster   – grobe Heuristik für verschleierten/Netzwerk-Code (zum manuellen Nachsehen)

Nur Standardbibliothek (+ `packaging`, falls vorhanden). Braucht Internet für pypi.org.
"""
from __future__ import annotations

import base64
import concurrent.futures as cf
import csv
import datetime as dt
import hashlib
import json
import re
import sys
import sysconfig
import urllib.error
import urllib.request
from importlib import metadata
from pathlib import Path

NEW_PROJECT_DAYS = 90      # Projekt erst so kurz auf PyPI
NEW_RELEASE_DAYS = 7       # Version erst so kurz veröffentlicht
SITE = Path(sysconfig.get_paths()["purelib"])
NOW = dt.datetime.now(dt.timezone.utc)

SUSPICIOUS = [
    (r"exec\(\s*(base64|zlib|marshal|bytes\.fromhex|codecs\.decode)", "exec auf dekodierte Daten"),
    (r"eval\(\s*(base64|zlib|marshal|compile\()", "eval auf dekodierte Daten"),
    (r"marshal\.loads\(", "marshal.loads (Bytecode laden)"),
    (r"exec\(\s*(urllib|requests|httpx)", "exec auf heruntergeladenen Code"),
    (r"(curl|wget)\s+[^\n]*\|\s*(ba)?sh", "curl|sh in Shell-Befehl"),
    (r"discord(app)?\.com/api/webhooks", "Discord-Webhook (Datenabfluss)"),
    (r"api\.telegram\.org/bot", "Telegram-Bot (Datenabfluss)"),
    (r"(\.ssh/id_|\.aws/credentials|login\.keychain|Cookies\.binarycookies|\.config/gcloud)",
     "Zugriff auf Zugangsdaten-Dateien"),
    (r"https?://(?!127\.|0\.0\.0\.0|10\.|192\.168\.)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}", "Netzwerkzugriff auf nackte IP-Adresse"),
    (r"[A-Za-z0-9+/]{400,}={0,2}", "sehr langer Base64-Block"),
]


# Bekannte, harmlose .pth-Dateien (von virtualenv/uv bzw. setuptools angelegt)
KNOWN_PTH = {
    "_virtualenv.pth": "import _virtualenv",
    "distutils-precedence.pth": "import os; var = 'SETUPTOOLS_USE_DISTUTILS'",
}


# Geprüfte, legitime Wechsel der Veröffentlichungs-Quelle: Paket -> (alt, neu, Begründung)
VERIFIED_PUBLISHER_MOVES = {
    "monotonic-alignment-search": (
        "GitHub: eginhard/monotonic_alignment_search",
        "GitHub: tts-hub/monotonic_alignment_search",
        "geprüft 2026-11-04: Repo-Umzug (gleiche Tags/Commits), installierter Code identisch mit Tag v0.2.2",
    ),
}


def norm(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def http_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "abc-spiel-audit/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return {"__status__": e.code}


def parse_time(s: str) -> dt.datetime:
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


# ------------------------------------------------------------------ Daten sammeln

def installed() -> dict[str, metadata.Distribution]:
    dists = {}
    for d in metadata.distributions(path=[str(SITE)]):
        name = d.metadata["Name"]
        if name:
            dists[norm(name)] = d
    return dists


def requirements_of(dist: metadata.Distribution, extras: set[str]) -> set[tuple[str, frozenset]]:
    try:
        from packaging.requirements import Requirement
    except ImportError:
        Requirement = None
    result = set()
    for raw in dist.requires or []:
        if Requirement:
            req = Requirement(raw)
            if req.marker:
                envs = [{"extra": e} for e in (extras or {""})]
                if not any(req.marker.evaluate(env) for env in envs):
                    continue
            result.add((norm(req.name), frozenset(req.extras)))
        else:
            if "extra ==" in raw:
                continue
            result.add((norm(re.split(r"[ ;<>=!~\[(]", raw, maxsplit=1)[0]), frozenset()))
    return result


def reachable(dists, roots: list[str]) -> set[str]:
    """Alle Pakete, die (inkl. Extras wie fsspec[http]) von den Wurzeln aus verlangt werden."""
    visited: set[tuple[str, frozenset]] = set()
    stack = [(norm(r), frozenset()) for r in roots]
    while stack:
        name, extras = stack.pop()
        if (name, extras) in visited or name not in dists:
            continue
        visited.add((name, extras))
        stack.extend(requirements_of(dists[name], set(extras)))
    return {name for name, _ in visited}


def publishers_of(name: str, version: str, files: list[dict]) -> set[str]:
    """PEP-740-Herkunftsnachweis: aus welcher CI (Trusted Publishing) stammt das Release?"""
    publishers = set()
    for f in files[:3]:
        data = http_json(f"https://pypi.org/integrity/{name}/{version}/{f['filename']}/provenance")
        for bundle in data.get("attestation_bundles", []) if isinstance(data, dict) else []:
            pub = bundle.get("publisher", {})
            publishers.add(f"{pub.get('kind', '?')}: {pub.get('repository') or pub.get('project') or '?'}")
    return publishers


def provenance(name: str, version: str, files: list[dict], proj: dict) -> tuple[str, bool]:
    """Text + Alarm, falls die Vorgängerversion einen Nachweis hatte und diese nicht (oder aus anderer Quelle)."""
    current = publishers_of(name, version, files)
    releases = sorted(
        ((min(f["upload_time_iso_8601"] for f in fs), v, fs) for v, fs in proj.get("releases", {}).items()
         if fs and v != version and not all(f.get("yanked") for f in fs)),
    )
    mine = min(f["upload_time_iso_8601"] for f in files)
    older = [r for r in releases if r[0] < mine]
    previous = publishers_of(name, older[-1][1], older[-1][2]) if older else set()
    if current:
        alarm = bool(previous) and not (current & previous)
        text = "Herkunftsnachweis ✓ " + ", ".join(sorted(current))
        move = VERIFIED_PUBLISHER_MOVES.get(name)
        if alarm and move and move[0] in previous and move[1] in current:
            return text + f" – Quellwechsel bekannt ({move[2]})", False
        if alarm:
            text += f" – ANDERE Quelle als Vorgänger ({', '.join(sorted(previous))})"
        return text, alarm
    if previous:
        return f"OHNE Herkunftsnachweis, Vorgänger {older[-1][1]} hatte einen ({', '.join(sorted(previous))})", True
    return "ohne Herkunftsnachweis (hatte das Projekt auch früher nie)", False


def pypi_info(name: str, version: str):
    proj = http_json(f"https://pypi.org/pypi/{name}/json")
    rel = http_json(f"https://pypi.org/pypi/{name}/{version}/json")
    return name, proj, rel


# ------------------------------------------------------------------ Prüfungen

def check_record(dist: metadata.Distribution) -> list[str]:
    problems = []
    try:
        record = dist.read_text("RECORD")
    except Exception:
        record = None
    if not record:
        return ["keine RECORD-Datei"]
    base = Path(dist.locate_file(""))
    for row in csv.reader(record.splitlines()):
        if len(row) < 2 or not row[1]:
            continue
        path, digest = row[0], row[1]
        if path.endswith(".pyc") or "__pycache__" in path:
            continue
        algo, _, expected = digest.partition("=")
        file = (base / path).resolve()
        if not file.exists():
            continue
        h = hashlib.new(algo, file.read_bytes()).digest()
        actual = base64.urlsafe_b64encode(h).rstrip(b"=").decode()
        if actual != expected:
            problems.append(f"Datei verändert: {path}")
    return problems


def scan_code(dist: metadata.Distribution) -> list[str]:
    hits = []
    for f in dist.files or []:
        if f.suffix != ".py" or any(part in ("tests", "test", "test_data", "testing") for part in f.parts):
            continue
        p = Path(dist.locate_file(f))
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for pattern, label in SUSPICIOUS:
            m = re.search(pattern, text)
            if m:
                line = text.count("\n", 0, m.start()) + 1
                hits.append(f"{label}: {f}:{line}")
    return hits


def check_autostart() -> list[str]:
    findings = []
    for pth in SITE.glob("*.pth"):
        for line in pth.read_text(errors="ignore").splitlines():
            if line.startswith(("import ", "import\t")):
                known = KNOWN_PTH.get(pth.name)
                if known and line.startswith(known):
                    continue
                findings.append(f"{pth.name}: {line[:160]}")
    for name in ("sitecustomize.py", "usercustomize.py"):
        if (SITE / name).exists():
            findings.append(f"{name} vorhanden")
    return findings


# ------------------------------------------------------------------ Hauptprogramm

def main() -> int:
    roots = sys.argv[1:]
    dists = installed()
    print(f"Umgebung: {sys.prefix}")
    print(f"Python {sys.version.split()[0]} · {len(dists)} Pakete in {SITE}\n")
    red, yellow = [], []
    vulns: dict[str, dict] = {}   # Paket -> {ids, fixed, texts}

    # 1. Herkunft
    for name, d in sorted(dists.items()):
        direct = d.read_text("direct_url.json")
        if direct:
            yellow.append(f"[Herkunft] {name}: nicht von PyPI installiert → {direct.strip()[:150]}")
        installer = (d.read_text("INSTALLER") or "").strip()
        if installer and installer not in ("uv", "pip"):
            yellow.append(f"[Herkunft] {name}: Installer «{installer}»")

    # 2./3. PyPI
    print("Frage PyPI ab …")
    with cf.ThreadPoolExecutor(max_workers=12) as pool:
        futures = [pool.submit(pypi_info, n, d.version) for n, d in dists.items()]
        results = [f.result() for f in futures]
    for name, proj, rel in sorted(results):
        version = dists[name].version
        if proj.get("__status__") == 404:
            red.append(f"[PyPI] {name}: Projekt existiert auf PyPI nicht (mehr) – evtl. entfernt (Malware?)")
            continue
        if rel.get("__status__") == 404:
            red.append(f"[PyPI] {name} {version}: Version auf PyPI nicht vorhanden – woher stammt sie?")
            continue
        if "__status__" in rel or "__status__" in proj:
            yellow.append(f"[PyPI] {name}: Abfrage fehlgeschlagen ({rel.get('__status__')})")
            continue
        seen_groups = []
        for v in rel.get("vulnerabilities", []):
            ids = {v.get("id", "")} | set(v.get("aliases", []))
            if any(i.startswith("MAL-") for i in ids):
                red.append(f"[MALWARE] {name} {version}: {', '.join(sorted(ids))}")
                continue
            if any(ids & g for g in seen_groups):
                for g in seen_groups:
                    if ids & g:
                        g |= ids
                continue
            seen_groups.append(set(ids))
            entry = vulns.setdefault(name, {"version": version, "count": 0, "fixed": set()})
            entry["count"] += 1
            entry["fixed"].update(v.get("fixed_in") or ["?"])
        files = rel.get("urls", [])
        if any(f.get("yanked") for f in files):
            reason = next((f.get("yanked_reason") for f in files if f.get("yanked")), "") or ""
            yellow.append(f"[PyPI] {name} {version}: Version zurückgezogen (yanked) {reason}")
        uploads = [parse_time(f["upload_time_iso_8601"]) for f in files if f.get("upload_time_iso_8601")]
        if uploads and (NOW - min(uploads)).days < NEW_RELEASE_DAYS:
            text, alarm = provenance(name, version, files, proj)
            (red if alarm else yellow).append(
                f"[Frisch] {name} {version}: erst vor {(NOW - min(uploads)).days} Tagen veröffentlicht – {text}")
        first = [parse_time(f["upload_time_iso_8601"])
                 for fs in proj.get("releases", {}).values() for f in fs if f.get("upload_time_iso_8601")]
        if first and (NOW - min(first)).days < NEW_PROJECT_DAYS:
            yellow.append(f"[Frisch] {name}: Projekt erst seit {(NOW - min(first)).days} Tagen auf PyPI")

    # 4. Herleitung
    if roots:
        base_tools = {"pip", "setuptools", "wheel", "uv"}
        needed = reachable(dists, roots)
        for name in sorted(set(dists) - needed - base_tools):
            yellow.append(f"[Herleitung] {name}: wird von keinem installierten Paket verlangt")
        for r in roots:
            if norm(r) not in dists:
                yellow.append(f"[Herleitung] {r}: angegeben, aber nicht installiert")

    # 5. Auto-Start
    for f in check_autostart():
        yellow.append(f"[Auto-Start] {f}")

    # 6./7. Integrität und Code
    print("Prüfe Prüfsummen und Code-Muster …\n")
    code_hits = []
    for name, d in sorted(dists.items()):
        for p in check_record(d):
            red.append(f"[Integrität] {name}: {p}")
        for h in scan_code(d):
            code_hits.append(f"{name}: {h}")

    def section(title, items):
        print(f"== {title} ({len(items)}) ==")
        for i in items:
            print("  " + i)
        print()

    def fixed_key(v):
        try:
            from packaging.version import Version
            return Version(v)
        except Exception:
            return v

    vuln_lines = []
    for name, e in sorted(vulns.items(), key=lambda kv: -kv[1]["count"]):
        fixes = sorted((f for f in e["fixed"] if f != "?"), key=fixed_key)
        text = f"behoben bis {fixes[-1]}" if fixes else ""
        if "?" in e["fixed"]:
            text += (", " if text else "") + "teils noch ohne Fix"
        vuln_lines.append(f"{name} {e['version']}: {e['count']} Lücke(n) – {text}")

    print("######## SUPPLY-CHAIN (Hinweise auf Angriffe / Manipulation) ########\n")
    section("ROT – sofort ansehen", red)
    section("GELB – prüfen", yellow)
    section("Code-Muster (Heuristik, zum Nachsehen – meist harmlos)", code_hits)
    print("######## BEKANNTE SICHERHEITSLÜCKEN (kein Angriff, aber veraltet) ########\n")
    section("Pakete mit bekannten Lücken", vuln_lines)
    print("Fazit Supply-Chain:", "auffällig ❌" if red else ("keine Angriffs-Hinweise, gelbe Punkte prüfen ⚠️"
                                                          if yellow else "keine Auffälligkeiten ✅"))
    print(f"Fazit Lücken: {sum(e['count'] for e in vulns.values())} bekannte Lücken in {len(vulns)} Paketen")
    return 1 if red else 0


if __name__ == "__main__":
    sys.exit(main())
