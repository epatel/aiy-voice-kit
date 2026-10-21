# AIY Voice Kit v1 on a current Raspberry Pi OS (Trixie)

Goal: run the [Google AIY Voice Kit v1](https://aiyprojects.withgoogle.com/voice-v1/) (Raspberry Pi 3 B + **Voice HAT**: two I2S MEMS mics,
a mono amplifier and an arcade button with LED) on **Raspberry Pi OS Lite Trixie** (kernel 6.18, Python 3.13), instead of Google's 2017
image (Raspbian Jessie, pi-gen 2017-07-05, Python 3.4).

Status (2026-10-21): **phases 0–6 done** (see [`PLAN.md`](PLAN.md)).
- On Trixie 64-bit the Voice HAT records and plays through the stock kernel overlay. The ALSA config gives volume, mic gain and shared access.
- The `aiy` Python library's Voice HAT parts (button, LED, audio, text-to-speech) run in a venv. Two Trixie breaks are fixed.
- A push-to-talk echo demo can run at boot.
- `make deploy` sets up a card from the Mac in one step; `make uninstall` reverses it.

Speaker playback is checked by ear; the real button still needs a check by hand.

## Why it isn't just `apt upgrade`

| Area | Google's image (2017) | Trixie |
|---|---|---|
| Sound driver | `googlevoicehat-soundcard` overlay + `i2s-mmap` | Same overlay, still in the kernel; `i2s-mmap` no longer exists (drop it). The HAT EEPROM's device tree is rejected, so `config.txt` must name the overlay |
| Volume / mic gain | `asound.conf`: softvol + ×30 mic boost | Same idea, but ×4: ×30 clips even quiet speech |
| Recording to WAV | `arecord`, stopped with SIGTERM | arecord 1.2.14 leaves a broken WAV header on SIGTERM; the library now repairs it |
| Python | 3.4, system pip, RPi.GPIO | 3.13, venv required (PEP 668), RPi.GPIO through `python3-rpi-lgpio` |
| Text-to-speech | `pico2wave` | Still in Debian non-free (enabled in the image); `tts.say` quoting fixed |
| Google Assistant | Assistant SDK / library | **Shut down.** Not ported; a replacement is a later decision |

## Layout

| Path | Contents |
|---|---|
| [`PLAN.md`](PLAN.md) | Phases, decisions and progress |
| [`port/README.md`](port/README.md) | Install guide and known gaps |
| [`port/DEPENDENCIES.md`](port/DEPENDENCIES.md) | Every dependency checked against Trixie, with test results per phase |
| `port/alsa/asound.conf` | ALSA config installed as `/etc/asound.conf` |
| `port/python/` | The Voice HAT parts of Google's `aiy` library, with this port's fixes (`port/python.patch` is the diff against upstream) |
| `Makefile` | Numbered menu (`make`) for deploy, status, tests, patches, uninstall. `HOST=` picks the Pi |
| `port/install.sh`, `deploy.sh`, `uninstall.sh` | Install on the Pi, copy + install from the Mac, remove |
| `port/systemd/` | `voice_echo_demo.service` |
| `port/tests/` | Device checks (silent by default) |
| [`docs/`](docs/README.md) | Unmodified snapshot of Google's AIY repo (commit in `COMMIT`), the upstream for the patch; index in `docs/README.md` |
| `cards/` | Notes for Claude Code (see `CLAUDE.md`) |
| `vendor/` | Baseline logs, recordings and the 2017 image backup. Kept out of git |

## Install

On a Pi 3 with the Voice HAT and a fresh Raspberry Pi OS Lite 64-bit (Trixie) card, with SSH key login and passwordless sudo.
[`port/README.md`](port/README.md) has the full guide: preparing the card, options, what gets installed, using it, and the known gaps.

```bash
make deploy HOST=pi@voice-kit.local                      # add ARGS=--echo-service to start the echo demo at boot
make reboot HOST=pi@voice-kit.local                      # config.txt changed: the Voice HAT appears after a reboot
make status test_hw test_echo HOST=pi@voice-kit.local    # silent checks
make test_play                                           # through the speaker, at 20 % volume
```

`port/install.sh` (run on the Pi by `deploy.sh`) installs the apt packages, comments out the onboard audio and adds the overlay in `config.txt`
(in a marked block), installs `/etc/asound.conf`, puts the library in `/opt/aiy/python` with a venv in `/opt/aiy/venv`, and installs the echo
demo service (disabled unless `--echo-service`; `--echo-args "…"` passes options such as `--greeting Hello`). It is safe to re-run.
`make uninstall` removes all of it and turns the onboard audio back on; apt packages stay.

## Licensing

This repo has no license of its own; each part keeps the license of the code it came from:
- `port/python/`: derived from Google's `aiyprojects-raspbian` Python library, **Apache-2.0** (`docs/aiyprojects-raspbian/LICENSE`).
- `docs/aiyprojects-raspbian/`: an unmodified snapshot under its upstream licenses (Apache-2.0; its kernel drivers are GPL-2.0).
- There are no kernel drivers in this port: the Voice HAT drivers are part of the Raspberry Pi kernel.
