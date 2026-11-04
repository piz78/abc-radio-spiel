#!/usr/bin/env bash
# Richtet eine Python-Umgebung für den Stimm-Klon ein (Apple Silicon Mac empfohlen).
#   ./setup.sh             → Chatterbox Multilingual (Standard, MIT-Lizenz)
#   ./setup.sh xtts        → Coqui XTTS-v2 (nur nicht-kommerziell)
#   ./setup.sh swissdial   → ESPnet SwissDial-TTS (8 Schweizer Dialekte, kein Stimm-Klon)
set -euo pipefail
cd "$(dirname "$0")"
ENGINE="${1:-chatterbox}"

if ! command -v uv >/dev/null 2>&1; then
  echo "Bitte zuerst «uv» installieren:  brew install uv"
  exit 1
fi

VENV=".venv-$ENGINE"
PYTHON_VERSION=3.11
[ "$ENGINE" = "swissdial" ] && PYTHON_VERSION=3.12   # ESPnet braucht Python ≥ 3.12
uv venv --python "$PYTHON_VERSION" "$VENV"
case "$ENGINE" in
  chatterbox)
    # setuptools<81 liefert pkg_resources, das das Wasserzeichen-Paket (resemble-perth) braucht.
    uv pip install --python "$VENV/bin/python" chatterbox-tts soundfile numpy "setuptools<81"
    ;;
  xtts)
    # PyTorch < 2.9: ab 2.9 verlangt coqui-tts zusätzlich torchcodec + FFmpeg-Bibliotheken.
    # six: wird von coqui-tts importiert, aber nicht als Abhängigkeit mitinstalliert.
    uv pip install --python "$VENV/bin/python" coqui-tts "torch<2.9" "torchaudio<2.9" six soundfile numpy
    ;;
  swissdial)
    # torch/torchaudio als passendes Paar fixieren (torchaudio 2.11.1 passt nicht zu torch 2.11.0).
    uv pip install --python "$VENV/bin/python" espnet espnet_model_zoo kaldiio soundfile numpy \
      "torch==2.11.0" "torchaudio==2.11.0"
    ;;
  *)
    echo "Unbekanntes Modell: $ENGINE (chatterbox, xtts oder swissdial)"
    exit 1
    ;;
esac

echo
echo "✅ Fertig. Test mit:"
echo "   tools/voice/$VENV/bin/python tools/voice/generate_clips.py --engine $ENGINE --vorschau"
