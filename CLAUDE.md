# CLAUDE.md

## About this project

A port of Google's AIY Voice Kit v1 software (Raspberry Pi 3 B + Voice HAT: I2S mics, amp, arcade button with LED) to Raspberry Pi OS Lite **Trixie** 64-bit
(kernel 6.18, Python 3.13). The kernel side is stock: the in-tree `googlevoicehat-soundcard` overlay. The work is an ALSA config, the Voice HAT parts of the
`aiy` Python library in a venv, a push-to-talk demo service, and install scripts. `PLAN.md` holds the phases, decisions and progress; read it when
continuing phase work. `port/DEPENDENCIES.md` records every change and test result. `README.md` and `port/README.md` (install guide, known gaps) are for people.

## Commands

Run from the repo root on the Mac; `make` alone shows the numbered menu. `HOST` defaults to the dev card `pi@voice-kit.local`.
- Install/update the Pi: `make deploy` (`ARGS="--echo-service"` etc. go to `port/install.sh`), then `make reboot` if it says so
- Silent checks: `make status test_hw test_echo`. With someone at the kit: `make test_play`, `make test_button`, `make say TEXT="…"`
- Regenerate `port/python.patch`: `make patches` (a hook does it after Claude's edits to `port/python/src/`)
- Check the agent docs: `make check_docs`. Remove everything from the Pi: `make uninstall`

## Cards

### Architecture
- [architecture](cards/architecture.md) — onboarding, or work spanning the HAT's GPIOs, kernel overlay, ALSA and the Python library; where files live on the Pi

### Domains
- [alsa-audio](cards/alsa-audio.md) — changing asound.conf, mic gain or volume, recording/playback that's silent, clipped, busy or not shared, level measurements
- [python-library](cards/python-library.md) — editing anything in port/python, the upstream patch, venv/apt dependencies, arecord/aplay behaviour in aiy.voice, tts, cloudspeech

### Features
- [echo-demo](cards/echo-demo.md) — the push-to-talk echo demo or its systemd service, button press/release timing, LED states
- [install-and-deploy](cards/install-and-deploy.md) — changing install.sh/deploy.sh/uninstall.sh or the Makefile, what install touches on the Pi (config.txt, asound.conf, /opt/aiy, the service), re-runs and uninstall
- [testing-on-device](cards/testing-on-device.md) — before running anything on the Pi: which card is in it, hosts and host keys, test scripts, ssh/pkill/grep traps, when sound is OK

### Decisions
- [trixie-only](cards/trixie-only.md) — someone asks about Bookworm, 32-bit or a Pi Zero, or a change that only works on one OS release
- [assistant-not-ported](cards/assistant-not-ported.md) — Google Assistant demos, or adding a voice assistant / speech backend (Claude, local STT, Home Assistant)
- [standing-defaults](cards/standing-defaults.md) — before installing any Python dependency, or adding anything that stores data

When you commit a change that adds non-obvious logic, settles an architectural choice,
or makes a card above wrong, update or add the card in that commit and keep this index
in sync. Proposed diffs and answers need no card edits. Cards stay self-contained: no
card links to another.

## Conventions

- `docs/aiyprojects-raspbian/` is an upstream snapshot: never edit it; port changes go in `port/python/`.
- `port/python.patch` must match `port/python/src/`; commit both. A hook regenerates the patch after Claude's edits there; after other edits run `port/make-patches.sh`.
- Python on the Pi only through the `/opt/aiy/venv` venv (`--system-site-packages`, `pip install --no-index`); dependencies come from apt.
- `vendor/` is gitignored: baseline logs, recordings and the 2017 image backup (no credentials in it; keep it that way).
- Ask before making sound on the kit, and keep it quiet in the evening. Leave the `lemic` card's `wyoming-satellite` setup as it is.
- Diagrams: mermaid, not ASCII.
