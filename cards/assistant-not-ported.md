# assistant-not-ported

Decision (2026-10-21): Google Assistant code from the AIY library is not ported. Its replacement is a **Home Assistant voice satellite**
(Linux Voice Assistant + a button/LED bridge, `install.sh --ha-satellite`).

## The choice

Leave `aiy/assistant/` and the `assistant_library_*` / `assistant_grpc_demo*` examples out of `port/python/`. For a voice assistant, the kit becomes an
HA satellite: wake word on the Pi, and HA's Assist pipeline does speech-to-text, home control or an LLM for general questions, and TTS. The language
(Swedish for this user) and the "smartness" are both set in HA, not on the Pi.

## Alternatives considered

- Port `aiy.assistant.grpc` to the Embedded Assistant API anyway.
- `wyoming-satellite`, as the old `lemic` card runs: archived January 2026, no button/LED support.
- Our own push-to-talk client for HA's Assist websocket API: no wake word, more code to own. Kept as the fallback if LVA stops working on a Pi 3 B.
- The Claude API directly (button → speech-to-text → Claude → TTS): needs a cloud speech-to-text and an API key on the device, and no home control.
- Fully local on the Pi (Vosk or whisper.cpp + Piper): the Pi 3 B is too slow.

## Why this won

- `google-assistant-library` was an armv7 binary never built for Python > 3.7 or arm64, and the Assistant SDK service it needs is shut down. Nothing to port.
- Linux Voice Assistant is maintained (by the Open Home Foundation), runs well on the Pi 3 B (about 4 % of one core while listening), and has a peripheral
  API, so the kit's button and LED work without changing it.
- The user already runs Home Assistant, and HA can use an LLM (Claude, OpenAI, …) as its conversation agent, so general questions come for free.

## When to revisit

If LVA's API or install changes in a way the pinned commit can't absorb, or if the user wants the kit to work without HA. Then the push-to-talk client
on top of `aiy.voice.audio` + `aiy.board` is the next option.
