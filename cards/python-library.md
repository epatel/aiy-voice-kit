# python-library

What is in `port/python/` (the `aiy` package for the Voice HAT), what was changed from Google's code and why, and how it's installed.

## Contents

A subset of upstream `aiyprojects-raspbian/src` (commit `964f07f5`, snapshot in `docs/aiyprojects-raspbian/`). Only files that apply to the Voice HAT:
- `aiy/board.py`: `Board`, `Button` (GPIO 23) and `Led`. `Led` resolves to `SingleColorLed` (GPIO 25, `GPIO.PWM`) because there's no KTD202x
  (`Leds.installed()` is false). `aiy/leds.py` is kept only because `board.py` imports it.
- `aiy/voice/audio.py`: `AudioFormat`, `record_file`, `Recorder`, `play_wav`, `FilePlayer`/`BytesPlayer`, all as `arecord`/`aplay` subprocesses on ALSA `default`.
- `aiy/voice/tts.py`: `say()` through `pico2wave` (+ a CLI).
- `aiy/cloudspeech.py` + `examples/voice/cloudspeech_demo.py`: **still upstream code for google-cloud-speech < 2.0** (`speech.types.*`); not ported, not tested.
- `examples/button_led.py`, `examples/voice/voice_recorder.py`, and this port's own `examples/voice/voice_echo_demo.py`.

Left out on purpose: vision, the Assistant (`aiy/assistant`, `assistant_*` demos: the service is shut down), and Voice/Vision Bonnet hardware (`pins.py`, buzzer, KTD LEDs).

## Changes from upstream (`port/python.patch`)

- `audio.record_file` → `_fix_wav_sizes()`: **arecord 1.2.14 (Trixie) exits on SIGTERM without finishing the WAV header**, leaving sizes of about 2 GB.
  Python's `wave` then fails with `MemoryError`. The function rewrites the RIFF and `data` sizes from the file size. `record_file_async` callers who stop arecord
  themselves still get the bad header. arecord also prints `read error: Interrupted system call`, which is harmless.
- `tts.say`: argument lists instead of `shell=True` (text with quotes, `$` or backticks broke it and was injectable). `RUN_DIR` falls back to the default
  temp dir when `/run/user/<uid>` is missing (services and non-login users).

## Upstream quirk (left as is)

If `play_wav`/`play_raw` raises inside `with FilePlayer()`, `Player.__exit__` → `join()` waits forever on an event that is never set, which hides the error.
Also note that `play_wav` is on `FilePlayer`, not on the base `Player`.

## Install and dependencies

- Venv at `/opt/aiy/venv`, created with `--system-site-packages`. Install with `pip install --no-index --no-build-isolation -e /opt/aiy/python`, so it's offline
  and every dependency comes from apt. Never install with pip into system Python (PEP 668), and don't add PyPI dependencies without a reason.
- apt: `python3-gpiozero`, `python3-lgpio` and `python3-rpi-lgpio` are preinstalled on Trixie. `python3-setuptools` is **not** on Lite but the editable install
  needs it. `libttspico-utils` comes from Debian non-free (enabled in the image), and `alsa-utils` is preinstalled.
- lgpio creates `.lgd-nfy*` files in the working directory, so run from a writable directory (services use `WorkingDirectory=~`).

## Changing it

Edit files under `port/python/src/`, then run `port/make-patches.sh` (`make patches`) to regenerate `port/python.patch`. Deploy with `make deploy`, which
copies the tree to `/opt/aiy/python` and re-runs the editable install. For a quick iteration,
`rsync -a --delete --exclude __pycache__ --exclude '*.egg-info' port/python/ pi@voice-kit.local:/opt/aiy/python/` is enough; the editable install picks it up.
