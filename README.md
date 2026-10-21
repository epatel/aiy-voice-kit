# AIY Voice Kit v1 on a current Raspberry Pi OS (Trixie)

Goal: run the [Google AIY Voice Kit v1](https://aiyprojects.withgoogle.com/voice-v1/) (Raspberry Pi 3 B + **Voice HAT**: two I2S MEMS mics,
a mono amplifier and an arcade button with LED) on **Raspberry Pi OS Lite Trixie** (kernel 6.18, Python 3.13), instead of Google's 2017
image (Raspbian Jessie, pi-gen 2017-07-05, Python 3.4).

Status (2026-10-21): **phases 0–4 done** (see [`PLAN.md`](PLAN.md)).
- On Trixie 64-bit the Voice HAT records and plays through the stock kernel overlay. The ALSA config gives volume, mic gain and shared access.
- The `aiy` Python library's Voice HAT parts (button, LED, audio, text-to-speech) run in a venv. Two Trixie breaks are fixed.
- A push-to-talk echo demo can run at boot.

Tested silently so far; speaker playback and the real button still need a check by ear and hand. The install script (phase 5) isn't written yet.

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
| [`port/DEPENDENCIES.md`](port/DEPENDENCIES.md) | Every dependency checked against Trixie, with test results per phase |
| `port/alsa/asound.conf` | ALSA config installed as `/etc/asound.conf` |
| `port/python/` | The Voice HAT parts of Google's `aiy` library, with this port's fixes (`port/python.patch` is the diff against upstream) |
| `port/systemd/` | `voice_echo_demo.service` |
| `port/tests/` | Device checks (silent by default) |
| `docs/aiyprojects-raspbian/` | Unmodified snapshot of Google's AIY repo (commit in `COMMIT`), the upstream for the patch |
| `cards/` | Notes for Claude Code (see `CLAUDE.md`) |
| `vendor/` | Baseline logs, recordings and the 2017 image backup. Kept out of git |

## Manual setup (until `install.sh` exists)

On a Pi 3 with the Voice HAT and a fresh Raspberry Pi OS Lite 64-bit (Trixie) card:

1. In `/boot/firmware/config.txt`, comment out `dtparam=audio=on` and add `dtparam=i2s=on` and `dtoverlay=googlevoicehat-soundcard`. Then copy
   `port/alsa/asound.conf` to `/etc/asound.conf` and reboot.
2. Run `sudo apt install python3-setuptools libttspico-utils` (`python3-rpi-lgpio` and `gpiozero` are preinstalled).
3. Copy `port/python/` to `/opt/aiy/python`, then run `python3 -m venv --system-site-packages /opt/aiy/venv` and
   `/opt/aiy/venv/bin/pip install --no-index --no-build-isolation -e /opt/aiy/python`.
4. Check it with `/opt/aiy/venv/bin/python port/tests/hardware_check.py`, adding `--play` for the speaker and `--button 15` for the button.

## Licensing

This repo has no license of its own; each part keeps the license of the code it came from:
- `port/python/`: derived from Google's `aiyprojects-raspbian` Python library, **Apache-2.0** (`docs/aiyprojects-raspbian/LICENSE`).
- `docs/aiyprojects-raspbian/`: an unmodified snapshot under its upstream licenses (Apache-2.0; its kernel drivers are GPL-2.0).
- There are no kernel drivers in this port: the Voice HAT drivers are part of the Raspberry Pi kernel.
