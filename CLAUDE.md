# CLAUDE.md

## About this project

A port of Google's AIY Voice Kit v1 software (Raspberry Pi 3 B + Voice HAT: I2S mics, amp, arcade button with LED) to Raspberry Pi OS Lite **Trixie** 64-bit
(kernel 6.18, Python 3.13). The kernel side is stock: the in-tree `googlevoicehat-soundcard` overlay. The work is an ALSA config, the Voice HAT parts of the
`aiy` Python library in a venv, a push-to-talk demo service, and (phase 5) install scripts. `PLAN.md` holds the phases, decisions and progress; read it when
continuing phase work. `port/DEPENDENCIES.md` records every change and test result. `README.md` is for people.

## Commands

There's no Makefile yet (phase 5). Run from the repo root on the Mac; the dev card is `pi@voice-kit.local`.
- Regenerate the patch after editing `port/python/src/`: `port/make-patches.sh`
- Deploy the library: `rsync -a --delete --exclude __pycache__ --exclude '*.egg-info' port/python/ pi@voice-kit.local:/opt/aiy/python/`
- Copy the tests: `rsync -a port/tests/ pi@voice-kit.local:voice-kit-port/tests/`
- Silent device check: `ssh pi@voice-kit.local 'cd ~; /opt/aiy/venv/bin/python voice-kit-port/tests/hardware_check.py'` (add `--play`, `--button 15` with someone there)
- Echo demo logic: the same with `echo_demo_check.py`

## Cards

### Architecture
- [architecture](cards/architecture.md) — onboarding, or work spanning the HAT's GPIOs, kernel overlay, ALSA and the Python library; where files live on the Pi

### Domains
- [alsa-audio](cards/alsa-audio.md) — changing asound.conf, mic gain or volume, recording/playback that's silent, clipped, busy or not shared, level measurements
- [python-library](cards/python-library.md) — editing anything in port/python, the upstream patch, venv/apt dependencies, arecord/aplay behaviour in aiy.voice, tts, cloudspeech

### Features
- [echo-demo](cards/echo-demo.md) — the push-to-talk echo demo or its systemd service, button press/release timing, LED states
- [testing-on-device](cards/testing-on-device.md) — before running anything on the Pi: which card is in it, hosts and host keys, test scripts, ssh/pkill/grep traps, when sound is OK

### Decisions
- [trixie-only](cards/trixie-only.md) — someone asks about Bookworm, 32-bit or a Pi Zero, or a change that only works on one OS release
- [assistant-not-ported](cards/assistant-not-ported.md) — Google Assistant demos, or adding a voice assistant / speech backend (Claude, local STT, Home Assistant)

When you commit a change that adds non-obvious logic, settles an architectural choice,
or makes a card above wrong, update or add the card in that commit and keep this index
in sync. Proposed diffs and answers need no card edits. Cards stay self-contained: no
card links to another.

## Conventions

- `docs/aiyprojects-raspbian/` is an upstream snapshot: never edit it; port changes go in `port/python/`.
- After editing `port/python/src/`, run `port/make-patches.sh` so `port/python.patch` matches, and commit both.
- Python on the Pi only through the `/opt/aiy/venv` venv (`--system-site-packages`, `pip install --no-index`); dependencies come from apt.
- `vendor/` is gitignored: baseline logs, recordings and the 2017 image backup (no credentials in it; keep it that way).
- Ask before making sound on the kit, and keep it quiet in the evening. Leave the `lemic` card's `wyoming-satellite` setup as it is.
- Diagrams: mermaid, not ASCII.
