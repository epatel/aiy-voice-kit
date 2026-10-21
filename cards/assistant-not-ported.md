# assistant-not-ported

Decision (2026-10-21): Google Assistant code from the AIY library is not ported, and what replaces it is deferred.

## The choice

Leave `aiy/assistant/` and the `assistant_library_*` / `assistant_grpc_demo*` examples out of `port/python/`, and list them as a known gap.
Hardware and local audio come first.

## Alternatives considered

- Port `aiy.assistant.grpc` to the Embedded Assistant API anyway.
- Replace it now with: the Claude API (button → speech-to-text → Claude → TTS), fully local (Vosk or whisper.cpp + Piper), or a Wyoming satellite that hands
  the button/LED to Home Assistant (what the old `lemic` card already does).

## Why this won

- `google-assistant-library` was an armv7 binary never built for Python > 3.7 or arm64, and the Assistant SDK service it needs is shut down. Nothing to port.
- The user chose "decide later": a replacement needs product choices (accounts, cloud vs. local, Home Assistant) that the hardware port doesn't.

## When to revisit

Once phases 0–6 are done, or when the user picks a voice backend. Then add a new example on top of `aiy.voice.audio` + `aiy.board` rather than reviving
`aiy.assistant`.
