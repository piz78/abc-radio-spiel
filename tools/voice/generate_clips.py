#!/usr/bin/env python3
"""
Erzeugt alle Sprech-Clips (Moderator + Fragen) mit einer geklonten Stimme – lokal auf dem Mac.

Ablauf:
  1. Manifest aller Clips holen (`swift run abc-clips`, gleiche Quelle wie die App).
  2. Referenz-Aufnahmen aus tools/voice/referenz/ laden (z.B. per AirDrop aus der App).
     Aufnahmen, deren Dateiname ein Clip-Schlüssel ist (greeting-1.m4a …), werden direkt übernommen.
  3. Fehlende Clips mit dem Modell erzeugen, Stille abschneiden, Lautstärke angleichen,
     als AAC (.m4a) nach ABCSpiel/Resources/Clips/ schreiben.

Beispiele:
  python generate_clips.py --vorschau                  # 15 Test-Clips nach tools/voice/vorschau/
  python generate_clips.py --buchstabe A,B             # nur Fragen A und B (+ Moderator)
  python generate_clips.py                             # alles, was noch fehlt
  python generate_clips.py --engine xtts               # anderes Modell
  python generate_clips.py --export-texte texte.md     # nur Sprechtexte als Liste ausgeben
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
VOICE_DIR = Path(__file__).resolve().parent
FRAGEN = REPO / "ABCSpiel" / "Resources" / "fragen.txt"
OUT_DIR = REPO / "ABCSpiel" / "Resources" / "Clips"
REF_DIR = VOICE_DIR / "referenz"
PREVIEW_DIR = VOICE_DIR / "vorschau"
LEXICON = VOICE_DIR / "aussprache.txt"
AUDIO_EXT = {".m4a", ".wav", ".caf", ".mp3", ".aif", ".aiff", ".flac"}
WORK_SR = 24000


def log(msg: str) -> None:
    print(msg, flush=True)


# ---------------------------------------------------------------- Manifest

def load_manifest(path: Path | None) -> list[dict]:
    if path:
        return json.loads(path.read_text(encoding="utf-8"))
    if not shutil.which("swift"):
        sys.exit("Fehler: `swift` nicht gefunden. Xcode installieren oder --manifest angeben.")
    log("Manifest wird mit `swift build` erzeugt …")
    subprocess.run(["swift", "build", "-c", "release", "--product", "abc-clips", "--package-path", str(REPO)],
                   check=True, stdout=subprocess.DEVNULL)
    bin_dir = subprocess.run(["swift", "build", "-c", "release", "--show-bin-path", "--package-path", str(REPO)],
                             check=True, capture_output=True, text=True).stdout.strip()
    out = subprocess.run([str(Path(bin_dir) / "abc-clips"), str(FRAGEN)], check=True, capture_output=True, text=True)
    return json.loads(out.stdout)


# ---------------------------------------------------------------- Audio-Hilfen

def have(tool: str) -> bool:
    return shutil.which(tool) is not None


def to_wav(src: Path, dst: Path, sr: int = WORK_SR) -> Path:
    """Beliebige Audiodatei → WAV mono 16 bit."""
    if have("afconvert"):
        subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{sr}", "-c", "1", str(src), str(dst)], check=True)
    elif have("ffmpeg"):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-ac", "1", "-ar", str(sr), str(dst)],
                       check=True)
    elif src.suffix.lower() == ".wav":
        shutil.copyfile(src, dst)
    else:
        sys.exit(f"Fehler: kann {src.name} nicht umwandeln (afconvert oder ffmpeg nötig).")
    return dst


def read_audio(path: Path):
    import numpy as np
    import soundfile as sf
    data, sr = sf.read(str(path), dtype="float32", always_2d=True)
    return data.mean(axis=1).astype(np.float32), sr


def resample(audio, sr_in: int, sr_out: int):
    import numpy as np
    if sr_in == sr_out or len(audio) == 0:
        return audio
    n = int(round(len(audio) * sr_out / sr_in))
    return np.interp(np.linspace(0, len(audio) - 1, n), np.arange(len(audio)), audio).astype(np.float32)


def polish(audio, sr: int, pad: float = 0.08):
    """Stille am Anfang/Ende abschneiden, Lautstärke angleichen (RMS, Spitzen begrenzt)."""
    import numpy as np
    if len(audio) == 0:
        return audio
    frame = max(1, int(sr * 0.02))
    n = len(audio) // frame
    if n > 0:
        rms = np.sqrt((audio[: n * frame].reshape(n, frame) ** 2).mean(axis=1) + 1e-12)
        threshold = max(rms.max() * 0.05, 1e-4)
        voiced = np.where(rms > threshold)[0]
        if len(voiced):
            start = max(0, voiced[0] * frame - int(pad * sr))
            end = min(len(audio), (voiced[-1] + 1) * frame + int(pad * sr))
            audio = audio[start:end]
    rms = float(np.sqrt((audio ** 2).mean() + 1e-12))
    gain = 10 ** (-20 / 20) / rms                      # Ziel: -20 dBFS RMS
    peak = float(np.abs(audio).max() + 1e-12)
    gain = min(gain, 0.89 / peak)                      # Spitzen max. -1 dBFS
    audio = (audio * gain).astype(np.float32)
    fade = min(len(audio) // 2, int(0.01 * sr))       # Klickfreie Ränder
    if fade > 0:
        ramp = np.linspace(0, 1, fade, dtype=np.float32)
        audio[:fade] *= ramp
        audio[-fade:] *= ramp[::-1]
    return audio


def write_clip(audio, sr: int, out_dir: Path, key: str) -> Path:
    """Schreibt <key>.m4a (AAC) – oder .wav, falls kein Encoder vorhanden ist."""
    import soundfile as sf
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob(f"{key}.*"):
        old.unlink()
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / f"{key}.wav"
        sf.write(str(wav), audio, sr, subtype="PCM_16")
        if have("afconvert"):
            dst = out_dir / f"{key}.m4a"
            subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "64000", str(wav), str(dst)], check=True)
        elif have("ffmpeg"):
            dst = out_dir / f"{key}.m4a"
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "aac", "-b:a", "64k",
                            str(dst)], check=True)
        else:
            dst = out_dir / f"{key}.wav"
            shutil.copyfile(wav, dst)
    return dst


def existing_clip(out_dir: Path, key: str) -> Path | None:
    for ext in (".m4a", ".wav", ".caf"):
        p = out_dir / f"{key}{ext}"
        if p.exists():
            return p
    return None


# ---------------------------------------------------------------- Text

def load_lexicon() -> list[tuple[re.Pattern, str]]:
    rules = []
    if LEXICON.exists():
        for line in LEXICON.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            word, replacement = (part.strip() for part in line.split("=", 1))
            if word:
                rules.append((re.compile(rf"(?<!\w){re.escape(word)}(?!\w)"), replacement))
    return rules


def prepare_text(text: str, lexicon) -> str:
    for pattern, replacement in lexicon:
        text = pattern.sub(replacement, text)
    text = text.replace("«", "").replace("»", "").replace("…", ",").replace(" – ", ", ")
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\s+([,.!?:])", r"\1", text)
    text = re.sub(r",+([.!?:]|$)", r"\1", text.strip())
    return text.strip(" ,")


# ---------------------------------------------------------------- Modelle

def pick_device(requested: str) -> str:
    if requested != "auto":
        return requested
    try:
        import torch
        if torch.cuda.is_available():
            return "cuda"
        if torch.backends.mps.is_available():
            return "mps"
    except Exception:
        pass
    return "cpu"


class ChatterboxEngine:
    """Resemble AI Chatterbox Multilingual (MIT-Lizenz). Nutzt die ersten ~10 s der Referenz."""

    def __init__(self, references: list[Path], args):
        import torch
        import perth
        if perth.PerthImplicitWatermarker is None:
            sys.exit(
                "Fehler: Das Wasserzeichen-Paket von Chatterbox (resemble-perth) lässt sich nicht laden – meist fehlt\n"
                "«pkg_resources». Beheben mit:\n"
                f'  uv pip install --python "{sys.executable}" "setuptools<81"'
            )
        from chatterbox.mtl_tts import ChatterboxMultilingualTTS
        device = pick_device(args.device)
        log(f"Lade Chatterbox Multilingual auf «{device}» (beim ersten Mal ca. 3 GB Download) …")
        if args.seed is not None:
            torch.manual_seed(args.seed)
        self.model = ChatterboxMultilingualTTS.from_pretrained(device=device)
        self.sr = self.model.sr
        self.args = args
        reference = build_reference(references, seconds=10.0)
        self.model.prepare_conditionals(str(reference), exaggeration=args.exaggeration)

    def synth(self, text: str):
        wav = self.model.generate(
            text,
            language_id="de",
            exaggeration=self.args.exaggeration,
            cfg_weight=self.args.cfg_weight,
            temperature=self.args.temperature,
        )
        return wav.squeeze(0).detach().cpu().numpy()


class XTTSEngine:
    """Coqui XTTS-v2 (Coqui Public Model License, nur nicht-kommerziell). Nutzt mehrere Referenzen."""

    def __init__(self, references: list[Path], args):
        import torch
        from TTS.api import TTS
        device = pick_device(args.device)
        if device == "mps":
            device = "cpu"  # XTTS läuft auf MPS nicht zuverlässig
        log(f"Lade XTTS-v2 auf «{device}» (beim ersten Mal ca. 2 GB Download, Lizenz bestätigen) …")
        if args.seed is not None:
            torch.manual_seed(args.seed)
        import warnings
        self.tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)
        self.sr = self.tts.synthesizer.output_sample_rate
        self.model = self.tts.synthesizer.tts_model
        cfg = self.model.config
        refs = [str(p) for p in convert_references(references)[:10]]
        # Stimme nur EINMAL auswerten (statt bei jedem Clip die Referenzen neu zu laden).
        with warnings.catch_warnings():
            warnings.filterwarnings("ignore", category=UserWarning, module="torchaudio")
            self.gpt_cond_latent, self.speaker_embedding = self.model.get_conditioning_latents(
                audio_path=refs,
                gpt_cond_len=cfg.gpt_cond_len,
                gpt_cond_chunk_len=cfg.gpt_cond_chunk_len,
                max_ref_length=cfg.max_ref_len,
                sound_norm_refs=cfg.sound_norm_refs,
            )
        self.settings = {
            "temperature": cfg.temperature,
            "length_penalty": cfg.length_penalty,
            "repetition_penalty": cfg.repetition_penalty,
            "top_k": cfg.top_k,
            "top_p": cfg.top_p,
            "speed": args.speed,
        }
        log(f"Stimme aus {len(refs)} Referenz-Aufnahme(n) ausgewertet.")

    def synth(self, text: str):
        import numpy as np
        out = self.model.inference(text, "de", self.gpt_cond_latent, self.speaker_embedding, **self.settings)
        return np.asarray(out["wav"], dtype=np.float32)


class SayEngine:
    """macOS `say` – kein Klon, nur zum Testen der Pipeline."""

    def __init__(self, references, args):
        if not have("say"):
            sys.exit("`say` gibt es nur auf macOS.")
        self.voice = args.say_voice
        self.sr = WORK_SR

    def synth(self, text: str):
        with tempfile.TemporaryDirectory() as tmp:
            wav = Path(tmp) / "say.wav"
            voice = ["-v", self.voice] if self.voice else []
            subprocess.run(["say", *voice, "-o", str(wav), "--file-format=WAVE",
                            f"--data-format=LEI16@{WORK_SR}", text], check=True)
            audio, sr = read_audio(wav)
            return resample(audio, sr, self.sr)


class DummyEngine:
    """Piepstöne statt Sprache – für automatische Tests ohne Modell."""

    def __init__(self, references, args):
        self.sr = WORK_SR

    def synth(self, text: str):
        import numpy as np
        t = np.arange(int(self.sr * (0.3 + 0.04 * len(text)))) / self.sr
        return (0.3 * np.sin(2 * np.pi * 440 * t)).astype(np.float32)


ENGINES = {"chatterbox": ChatterboxEngine, "xtts": XTTSEngine, "say": SayEngine, "dummy": DummyEngine}


# ---------------------------------------------------------------- Referenzen

_converted: dict[Path, Path] = {}
_tmpdir = tempfile.TemporaryDirectory()


def convert_references(references: list[Path]) -> list[Path]:
    result = []
    for ref in references:
        if ref not in _converted:
            _converted[ref] = to_wav(ref, Path(_tmpdir.name) / f"{len(_converted)}-{ref.stem}.wav")
        result.append(_converted[ref])
    return result


def build_reference(references: list[Path], seconds: float) -> Path:
    """Fügt die Referenzen (Referenz-Sätze zuerst) zu einer Datei von max. `seconds` zusammen."""
    import numpy as np
    import soundfile as sf
    pieces, total = [], 0.0
    gap = np.zeros(int(0.25 * WORK_SR), dtype=np.float32)
    for wav in convert_references(references):
        audio, sr = read_audio(wav)
        audio = polish(resample(audio, sr, WORK_SR), WORK_SR, pad=0.05)
        pieces += [audio, gap]
        total += len(audio) / WORK_SR + 0.25
        if total >= seconds:
            break
    combined = np.concatenate(pieces)[: int(seconds * WORK_SR)]
    out = Path(_tmpdir.name) / "referenz.wav"
    sf.write(str(out), combined, WORK_SR, subtype="PCM_16")
    log(f"Referenz: {len(combined) / WORK_SR:.1f} s aus {min(len(references), len(pieces) // 2)} Aufnahme(n)")
    return out


def find_references(ref_dir: Path) -> list[Path]:
    files = [p for p in sorted(ref_dir.glob("*")) if p.suffix.lower() in AUDIO_EXT]
    # Eigene Referenz-Sätze zuerst, dann längere Aufnahmen.
    return sorted(files, key=lambda p: (not p.stem.startswith("ref-"), -p.stat().st_size))


# ---------------------------------------------------------------- Hauptprogramm

def select(manifest: list[dict], args) -> list[dict]:
    clips = [c for c in manifest if not c["key"].startswith("ref-")]
    if args.keys:
        wanted = set(args.keys.split(","))
        return [c for c in clips if c["key"] in wanted]
    if args.nur_moderator:
        clips = [c for c in clips if not c["key"].startswith("q-")]
    if args.nur_fragen:
        clips = [c for c in clips if c["key"].startswith("q-")]
    if args.buchstabe:
        letters = {l.strip().lower() for l in args.buchstabe.split(",")}
        clips = [c for c in clips if not c["key"].startswith("q-") or c["key"].split("-")[1] in letters]
    return clips


def export_texts(manifest: list[dict], path: Path) -> None:
    lines = ["# Sprechtexte ABC", ""]
    group = None
    for clip in manifest:
        if clip["group"] != group:
            group = clip["group"]
            lines += ["", f"## {group}", ""]
        lines.append(f"- `{clip['key']}` – {clip['text']}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    log(f"{len(manifest)} Texte → {path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--engine", choices=ENGINES, default="chatterbox")
    parser.add_argument("--referenz", type=Path, default=REF_DIR, help="Ordner mit Referenz-Aufnahmen")
    parser.add_argument("--manifest", type=Path, help="Manifest-JSON statt `swift run abc-clips`")
    parser.add_argument("--ausgabe", type=Path, default=OUT_DIR, help="Zielordner der Clips")
    parser.add_argument("--vorschau", action="store_true",
                        help=f"Nur ein paar Clips nach {PREVIEW_DIR.relative_to(REPO)} (zum Anhören)")
    parser.add_argument("--buchstabe", help="Nur Fragen dieser Buchstaben, z.B. A,B")
    parser.add_argument("--nur-moderator", action="store_true")
    parser.add_argument("--nur-fragen", action="store_true")
    parser.add_argument("--keys", help="Nur diese Clip-Schlüssel (Komma-getrennt)")
    parser.add_argument("--limit", type=int, help="Höchstens so viele Clips erzeugen")
    parser.add_argument("--neu", action="store_true", help="Vorhandene Clips überschreiben")
    parser.add_argument("--keine-eigenen", action="store_true",
                        help="Eigene Aufnahmen nicht direkt als Clips übernehmen")
    parser.add_argument("--export-texte", type=Path, help="Nur alle Sprechtexte als Markdown ausgeben")
    parser.add_argument("--device", default="auto", help="auto, mps, cpu oder cuda")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--exaggeration", type=float, default=0.5, help="Chatterbox: Ausdruck (0.25–1.0)")
    parser.add_argument("--cfg-weight", type=float, default=0.5, help="Chatterbox: Tempo/Treue (0.2–0.8)")
    parser.add_argument("--temperature", type=float, default=0.8, help="Chatterbox: Variation")
    parser.add_argument("--speed", type=float, default=1.0, help="XTTS: Sprechtempo (0.8–1.3)")
    parser.add_argument("--say-voice", default="Anna", help="Stimme für --engine say (leer = Systemstimme)")
    args = parser.parse_args()

    manifest = load_manifest(args.manifest)
    if args.export_texte:
        export_texts(manifest, args.export_texte)
        return 0

    out_dir = args.ausgabe
    clips = select(manifest, args)
    if args.vorschau:
        out_dir = PREVIEW_DIR
        moderator = [c for c in clips if not c["key"].startswith("q-")][:5]
        questions = [c for c in clips if c["key"].startswith("q-")][:10]
        clips = moderator + questions
        args.neu = True

    keys = {c["key"] for c in manifest}
    references = find_references(args.referenz) if args.referenz.exists() else []

    # 1) Eigene Aufnahmen mit Clip-Namen direkt übernehmen (echte Mundart schlägt jeden Klon).
    adopted = set()
    if not args.keine_eigenen and not args.vorschau:
        for ref in references:
            if ref.stem in keys and not ref.stem.startswith("ref-"):
                if existing_clip(out_dir, ref.stem) and not args.neu:
                    adopted.add(ref.stem)
                    continue
                audio, sr = read_audio(convert_references([ref])[0])
                write_clip(polish(audio, sr), sr, out_dir, ref.stem)
                adopted.add(ref.stem)
        if adopted:
            log(f"{len(adopted)} eigene Aufnahme(n) übernommen.")

    todo = [c for c in clips if c["key"] not in adopted and (args.neu or not existing_clip(out_dir, c["key"]))]
    if args.limit:
        todo = todo[: args.limit]
    if not todo:
        log("Nichts zu tun – alle Clips sind vorhanden. (--neu zum Überschreiben)")
        return 0
    if args.engine in ("chatterbox", "xtts") and not references:
        sys.exit(f"Fehler: keine Referenz-Aufnahmen in {args.referenz}. Siehe tools/voice/README.md.")

    engine = ENGINES[args.engine](references, args)
    lexicon = load_lexicon()
    log(f"Erzeuge {len(todo)} Clip(s) → {out_dir}")
    started = time.time()
    failures = 0
    for i, clip in enumerate(todo, 1):
        text = prepare_text(clip["text"], lexicon)
        t0 = time.time()
        try:
            audio = polish(engine.synth(text), engine.sr)
            dst = write_clip(audio, engine.sr, out_dir, clip["key"])
            log(f"[{i}/{len(todo)}] {dst.name:<34} {len(audio) / engine.sr:4.1f} s  "
                f"({time.time() - t0:.1f} s)  {clip['text']}")
        except Exception as error:  # einzelne Fehler überspringen, Rest weiter erzeugen
            failures += 1
            log(f"[{i}/{len(todo)}] FEHLER bei {clip['key']}: {error}")
    log(f"Fertig in {(time.time() - started) / 60:.1f} min, {failures} Fehler.")
    if args.vorschau:
        log(f"Anhören: open {out_dir}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
