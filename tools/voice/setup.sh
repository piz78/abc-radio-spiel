#!/usr/bin/env bash
# Richtet eine Python-Umgebung für den Stimm-Klon ein (Apple Silicon Mac empfohlen).
#   ./setup.sh             → Chatterbox Multilingual (Standard, MIT-Lizenz)
#   ./setup.sh xtts        → Coqui XTTS-v2 (nur nicht-kommerziell)
set -euo pipefail
cd "$(dirname "$0")"
ENGINE="${1:-chatterbox}"

if ! command -v uv >/dev/null 2>&1; then
  echo "Bitte zuerst «uv» installieren:  brew install uv"
  exit 1
fi

VENV=".venv-$ENGINE"
uv venv --python 3.11 "$VENV"
case "$ENGINE" in
  chatterbox)
    # setuptools<81 liefert pkg_resources, das das Wasserzeichen-Paket (resemble-perth) braucht.
    uv pip install --python "$VENV/bin/python" chatterbox-tts soundfile numpy "setuptools<81"
    ;;
  xtts)
    # PyTorch < 2.9: ab 2.9 verlangt coqui-tts zusätzlich torchcodec + FFmpeg-Bibliotheken.
    uv pip install --python "$VENV/bin/python" coqui-tts "torch<2.9" "torchaudio<2.9" soundfile numpy
    ;;
  *)
    echo "Unbekanntes Modell: $ENGINE (chatterbox oder xtts)"
    exit 1
    ;;
esac

echo
echo "✅ Fertig. Test mit:"
echo "   tools/voice/$VENV/bin/python tools/voice/generate_clips.py --engine $ENGINE --vorschau"
