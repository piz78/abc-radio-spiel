# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SwiftUI iOS app (iOS 17+, Xcode 16+) that recreates the feel of a Swiss radio quiz at home: one letter, 45 seconds, at least twelve correct answers. A moderator named "Ruedi" speaks every line. Docs, code comments and commit messages are in German; everything the player sees or hears is Swiss German (Mundart), including questions, moderator lines, UI labels and error messages. Keep that split.

## Commands

```bash
python3 tools/validate_questions.py                # check fragen.txt (format, first letter, duplicates, counts)
swift test                                         # Core logic tests (macOS, no simulator needed)
swift test --filter ClipCatalogTests/testManifestJSON   # single test
swift run abc-clips ABCSpiel/Resources/fragen.txt  # print the clip manifest as JSON

# Build the app (the Xcode project has no test target; tests only run via `swift test`)
xcodebuild -project ABCSpiel.xcodeproj -scheme ABCSpiel -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

CI (`.github/workflows/ios.yml`) runs on every push: the validator, `swift test`, the manifest, the voice generator with `--engine dummy` and `--engine say`, then the simulator build. After editing `generate_clips.py`, test it without a model the same way (needs `numpy` and `soundfile`). Always pass `--ausgabe`, because the default output is the real `ABCSpiel/Resources/Clips/`:

```bash
python3 tools/voice/generate_clips.py --engine say --keys q-b-bern,greeting-2 --say-voice "" --ausgabe "$(mktemp -d)"
```

## Architecture

**`ABCSpiel/Core` is compiled twice.** The Xcode target includes it as plain source, and `Package.swift` exposes the same folder as the `ABCCore` package for `swift test` and `abc-clips`. As a result:
- Core may only import Foundation, since it has to build on macOS. Anything touching UIKit, AVFoundation or Speech goes in `Services/` or `Views/`.
- App code never writes `import ABCCore`. Only the API `abc-clips` calls needs to be `public`.
- Tests use `@testable import ABCCore`, and several run against the real `fragen.txt`.

The Xcode project uses a synchronized folder, so new files under `ABCSpiel/` need no `project.pbxproj` edit.

**Game flow.** `GameController` (`Views/`) is the state machine: `intro → countdown → playing → finished`. It owns the async flow tasks and ties together the voice, the speech recognizer and the timer. `GameRound` (`Core/`) is a pure value type with injected time; random choices take an injected RNG (`SeededGenerator`). Keep new game logic in Core in this style so it stays testable. `AppModel` holds the question bank, settings, stats and voice, and `applySettings()` pushes settings to the services.

**Clip system (the part that spans the most files).** Every spoken line is a `Clip` with a stable key:
- `ModeratorScript` defines all moderator lines. `Question.clipKey` derives question keys from the answer (`q-b-bern`).
- `ClipCatalog` lists all clips. It is the single source for the in-app recording studio and, through `abc-clips`, for `tools/voice/generate_clips.py`.
- At runtime `ClipLibrary.playlist(for:)` resolves a clip in this order: own recording of the whole sentence (`Documents/Stimm/`) → all building blocks → bundled clip of the whole sentence (`Resources/Clips/`). `ModeratorVoice` falls back to `AVSpeechSynthesizer` when that returns nothing.
- Sentences containing numbers are assembled from `blocks` ("SBB principle": "Du hesch …" + "föifevierzg" + "… Sekunde."). If any block is missing, the whole sentence goes to the iOS voice; recorded and synthesized parts are never mixed within a sentence.

Consequences when changing content:
- Bundled clips are looked up by filename at the bundle root, so keys must be unique and file-safe.
- A changed answer changes the key and orphans its clip (rename or regenerate the `.m4a`).
- A changed prompt or moderator text keeps its key, so the old audio keeps playing until regenerated (`--keys … --neu`).
- A new moderator line must be added to `ClipCatalog.moderatorClips`, or `testEveryPlayedClipIsInCatalog` fails. A new round-time or target option goes in `GameOptions` and may need a new number block.
- `tools/voice/moderator-texte.md` is maintained by hand: update it when `ModeratorScript` texts change, because `split_fragen.py` reads its blocks and keys.
- `split_fragen.py` matches audio to questions by their order in `fragen.txt`, so that order has to match the recording being split.

## Question database

`ABCSpiel/Resources/fragen.txt`, one per line: `Letter | Question | Answer | Alternative;Alternative`. Rules enforced by the validator and tests:
- The answer starts with the letter, compared after folding diacritics.
- No duplicate questions or answers within a letter, and at least 20 questions per letter.
- Questions must not contain a pass word (`weiter`, `wiiter`, `passe`, `pass`), because speech recognition would treat it as skipping.
- `ModeratorScript.letterExamples` ("B wie …") must not be an answer anywhere in the file.

## Voice tooling

`tools/voice/README.md` is the full guide to the local TTS pipeline (Chatterbox, XTTS, SwissDial), `split_fragen.py` and `audit_env.py`. Things to respect:
- `tools/voice/referenz/` holds recordings of a real person's voice and is deliberately gitignored. Never commit it, and only clone voices with consent.
- Each engine has its own venv from `tools/voice/setup.sh <engine>`, at `tools/voice/.venv-<engine>/`.
- Only some clips exist so far, so missing questions are read by the iOS voice. That is expected, not a bug. Check `ABCSpiel/Resources/Clips/` for what is there.
