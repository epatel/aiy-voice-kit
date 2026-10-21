# AIY Voice Kit v1 on Raspberry Pi OS Trixie: install

Turns a freshly flashed **Raspberry Pi OS Lite (64-bit) Trixie** card into a working Voice Kit v1: the Voice HAT's mics and speaker through ALSA
(shared, with volume and mic gain), the arcade button and LED, the `aiy` Python library with text-to-speech, and an optional push-to-talk echo demo at boot.

## What you need

- A Raspberry Pi 3 B with the **Voice HAT** (Voice Kit v1), assembled as in Google's guide. The Voice Bonnet (Voice Kit v2) is a different board and isn't covered.
- A computer with this repo, `make`, `rsync` and `ssh`. No downloads: everything comes from the Raspberry Pi OS apt repos.

## Prepare the SD card

1. **Flash with [Raspberry Pi Imager](https://www.raspberrypi.com/software/).** Choose the device *Raspberry Pi 3*, then **Raspberry Pi OS Lite (64-bit)** (Trixie).
2. **Fill in Imager's customisation tabs:**
   - *Hostname:* `voice-kit` (the Makefile defaults to `pi@voice-kit.local`).
   - *Localisation:* your time zone and Wi-Fi country.
   - *User:* `pi` and a password.
   - *Wi-Fi:* SSID and password. The Pi 3 B only has 2.4 GHz Wi-Fi; Ethernet works too.
   - *Remote Access:* turn on **Enable SSH** with **public key authentication**, and paste your public key (for example `~/.ssh/id_ed25519.pub`).
3. **First boot**, then connect:

   ```bash
   ssh pi@voice-kit.local
   ```

   *"REMOTE HOST IDENTIFICATION HAS CHANGED"*: every newly flashed card gets a new host key. Run `ssh-keygen -R voice-kit.local` and connect again.
4. **Passwordless sudo**, which `deploy.sh` needs because it runs `sudo` over a non-interactive ssh. Check it with
   `ssh pi@voice-kit.local sudo -n true && echo ok`. If that fails, run this once (it asks for the password):

   ```bash
   ssh -t pi@voice-kit.local 'echo "pi ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/010_pi-nopasswd && sudo chmod 0440 /etc/sudoers.d/010_pi-nopasswd && sudo visudo -c'
   ```

## Install

From this repo on your computer:

```bash
make deploy          # or: port/deploy.sh pi@voice-kit.local   (copies port/ to ~/voice-kit-port, runs install.sh)
make reboot          # the Voice HAT appears after the reboot
make status test_hw  # silent checks
```

Use `HOST=pi@<host>` for another Pi. Options go through `ARGS`, for example `make deploy ARGS="--echo-service --echo-args '--greeting Hello'"`:

| install.sh option | Effect |
|---|---|
| `--echo-service` / `--no-echo-service` | enable / disable the echo demo at boot. With neither, a re-run keeps the current state (new installs: disabled) |
| `--echo-args "…"` | options for `voice_echo_demo.py`: `--greeting TEXT`, `--min_seconds`, `--max_seconds`, `--device` |
| `--ha-satellite` / `--no-ha-satellite` | enable / disable the Home Assistant voice satellite (see below). Can't be combined with the echo demo |
| `--ha-name NAME` | the satellite's name in Home Assistant (default: the hostname) |
| `--user NAME` | user for the service and the `audio`/`gpio` groups (default: the sudo user, or `pi`) |

On the Pi itself: `cd ~/voice-kit-port && sudo ./install.sh [options]`. The install takes under two minutes and is safe to re-run.
`make uninstall` (or `sudo ./uninstall.sh`) removes everything it added and turns the onboard audio back on; the apt packages stay.

## What gets installed

| Item | Where |
|---|---|
| apt packages | `alsa-utils python3-venv python3-setuptools python3-gpiozero python3-lgpio python3-rpi-lgpio libttspico-utils` (most are preinstalled) |
| Voice HAT overlay | marked block in `/boot/firmware/config.txt` (`dtparam=i2s=on`, `dtoverlay=googlevoicehat-soundcard`); `dtparam=audio=on` is commented out |
| ALSA config | `/etc/asound.conf`: shared playback/capture (dmix/dsnoop), `Master` volume, ×4 mic gain, as the `default` device |
| Python library + examples | `/opt/aiy/python` (editable install) in the venv `/opt/aiy/venv` (`--system-site-packages`; all dependencies come from apt) |
| Volume control | `aiy-voice-volume.service`: creates `Master` at boot if it's missing (it only appears after the first playback), starting at 30 % |
| Echo demo | `voice_echo_demo.service` (disabled unless `--echo-service`) |
| HA satellite (`--ha-satellite`) | PipeWire (configured to use the ALSA devices above), Linux Voice Assistant in `/opt/aiy/linux-voice-assistant`, `linux-voice-assistant.service` and `lva_bridge.service` |
| Groups | the user is added to `audio` and `gpio` |

No kernel modules are built: the Voice HAT driver is part of the Raspberry Pi kernel, so kernel updates need nothing extra.

## Using it

**Echo demo:** hold the arcade button and speak, release to hear it back. The LED is on while recording and pulses while playing.

```bash
sudo systemctl enable --now voice_echo_demo     # or install with --echo-service
journalctl -u voice_echo_demo -f
```

**Volume:** `amixer sset Master 30%` (kept across reboots). **Speech:**
`/opt/aiy/venv/bin/python -m aiy.voice.tts "Hello"`. **Plain ALSA:** `arecord -f S16_LE -r 16000 -c 1 -d 3 test.wav && aplay test.wav`.

In your own code, run it with `/opt/aiy/venv/bin/python` from a writable directory (lgpio creates `.lgd-nfy*` files in the working directory):

```python
import threading

from aiy.board import Board, Led
from aiy.voice.audio import AudioFormat, record_file, play_wav
from aiy.voice import tts

with Board() as board:
    tts.say('Hold the button and speak')
    board.button.wait_for_press()
    # Set the release callback right away, so a quick release isn't missed
    # while arecord starts.
    released = threading.Event()
    board.button.when_released = released.set
    board.led.state = Led.ON
    record_file(AudioFormat.CD, filename='note.wav', filetype='wav',
                wait=released.wait)
    board.led.state = Led.OFF
    play_wav('note.wav')
```

Examples are in `/opt/aiy/python/src/examples/` (`button_led.py`, `voice/voice_recorder.py`, `voice/voice_echo_demo.py`).
Stop the echo demo first if it's running: it holds the button and LED. See [`DEPENDENCIES.md`](DEPENDENCIES.md) for everything that changed from Google's stack and why.

## Home Assistant voice satellite

```bash
make deploy ARGS="--no-echo-service --ha-satellite"   # first time ~10 minutes: Linux Voice Assistant and its Python packages
```

The kit becomes a voice satellite for [Home Assistant](https://www.home-assistant.io/voice_control/) using
[Linux Voice Assistant](https://github.com/OHF-Voice/linux-voice-assistant), the successor of `wyoming-satellite`. Say **"Okay Nabu"**, or press the
button, and speak. Home Assistant turns the speech into text, runs the command (or asks an LLM, if you set one up), and the reply is spoken on the kit.

| Button | Action |
|---|---|
| short press | start listening; while it's listening or speaking: stop; while a timer rings: stop the timer |
| hold 2 s | mute the microphone |
| any press while muted | unmute |

| LED | State |
|---|---|
| on | listening |
| blinking | Home Assistant is thinking, or a timer is ringing |
| pulsing | speaking |
| faint blip | microphone muted |
| three blinks, repeating | not connected to Linux Voice Assistant or Home Assistant |

**In Home Assistant:** the kit shows up under Settings → Devices & services as a discovered **ESPHome** device (port 6053). Pick an assistant for it on
its device page. The assistant needs speech-to-text and text-to-speech. Home Assistant Cloud has them; locally, run Whisper and Piper. On HA OS
they're apps (add-ons). On HA in Docker, run them as containers, for Swedish:

```bash
docker run -d --name wyoming-whisper --restart unless-stopped -p 10300:10300 -v ~/wyoming/whisper:/data rhasspy/wyoming-whisper --model small-int8 --language sv
docker run -d --name wyoming-piper --restart unless-stopped -p 10200:10200 -v ~/wyoming/piper:/data rhasspy/wyoming-piper --voice sv_SE-nst-medium
```

Add both with the **Wyoming Protocol** integration (ports 10300 and 10200), then create an assistant that uses them. If Docker runs on a 32-bit OS
on a 64-bit Pi, add `--platform linux/arm64 --security-opt seccomp=unconfined` to both commands. For general questions, set the assistant's
conversation agent to an LLM integration and turn on "Prefer handling commands locally".

Logs: `make lva_logs`. LVA keeps its own settings (wake words, volume) in `/opt/aiy/linux-voice-assistant/preferences.json`; the overall volume is
still `Master`.

## Known gaps

- **Not checked by hand yet:** the real arcade button, the LED pulse, and the ×4 mic gain with normal-voice speech (chosen from quiet speech).
  Speaker playback works (`make test_play`: recording and TTS at 20 %).
- **The echo demo loses the first ~0.25 s** of each recording (arecord start-up), and each recording starts with a ~200 ms mic thump.
- **`voice_recorder.py` and `button_led.py`** are carried over unchanged but haven't been run (they need button presses).
- **Google Assistant** demos aren't ported: the service is shut down; the HA satellite replaces them. **Cloud Speech** (`aiy.cloudspeech`, `cloudspeech_demo.py`) is still the upstream
  code for `google-cloud-speech` < 2.0 and isn't ported or tested.
- **`record_file_async`** callers that stop arecord themselves get a WAV header with wrong sizes (arecord 1.2.14); `record_file` repairs it.
- **32-bit Trixie** and **Bookworm** aren't tested. Bookworm will probably work but isn't a target.
- **HA satellite:** Swedish speech-to-text with Whisper `small-int8` on a Pi 5 took ~5.7 s per question; Linux Voice Assistant calls
  itself experimental.
