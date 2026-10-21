# Dependencies to port: AIY Voice Kit v1 → Raspberry Pi OS Trixie

Phase 1 output (2026-10-21). The target is **Trixie** (kernel 6.18), on a Raspberry Pi 3 B. The 64-bit `bcm2711`/v8 build comes first, then 32-bit `bcm2709`/v7.
Bookworm (6.12) was checked too and needs nothing different, but it was dropped as a target on 2026-10-21. Trixie's Raspberry Pi repo has
`linux-image-rpi-v8 6.18.50`, plus `python3-rpi-lgpio 0.6`, `python3-lgpio 0.2.2` and `python3-gpiozero 2.0.1` for arm64 and armhf (**D**). Baseline: the `lemic` card (Bookworm 64-bit, kernel 6.6.51, Python 3.11.2; see `vendor/baseline/SUMMARY.md`), plus
a backup of Google's 2017 image (`vendor/hepp-extract/`).

Each finding is marked by how it was checked:
- **H**: checked against `github.com/raspberrypi/linux` branches `rpi-6.6.y`, `rpi-6.12.y` and `rpi-6.18.y` on 2026-10-21.
- **D**: checked against the Debian archive (`api.ftp-master.debian.org/madison`) or `apt-cache policy` on the card, on 2026-10-21.
- **B**: seen on the baseline card.
- **C**: read in the upstream source. That's `aiyprojects-raspbian`, vendored at `../vision-kit/docs/aiyprojects-raspbian/` and to be copied into this repo's `docs/`.
- **?**: not yet checked; confirm on the device (phase 2 or 3).

## Status: Phase 5 install scripts (2026-10-21)

- **`port/install.sh`** (run with sudo from `~/voice-kit-port`; `deploy.sh` copies `port/` there first). apt: `alsa-utils python3-venv python3-setuptools
  python3-gpiozero python3-lgpio python3-rpi-lgpio`, then `libttspico-utils` separately (a warning, not an error, if non-free is off). Adds the user to `audio`, `gpio`.
- **config.txt**: `dtparam=audio=on` becomes `#dtparam=audio=on  # aiy-voice-kit: …` and a `# >>> aiy-voice-kit` block adds `dtparam=i2s=on` +
  `dtoverlay=googlevoicehat-soundcard`. Skipped if the overlay line is already there (hand setups). Backup `config.txt.orig-aiy` (`cp -n`).
- **asound.conf**: a foreign `/etc/asound.conf` is kept as `.orig-aiy`; ours is recognised by its "AIY Voice HAT" header.
- **Echo service**: `--echo-service` / `--no-echo-service`; with neither, a re-run keeps the current state and `ExecStart` arguments. `--echo-args` is
  sed-escaped; `deploy.sh` quotes options with `printf %q` because macOS's bash 3.2 has no `${*@Q}`.
- **`port/uninstall.sh`**: removes the service, `/opt/aiy`, our asound.conf (or restores the `.orig-aiy`), the config.txt block and hand-setup lines, and
  turns `dtparam=audio=on` back on. Packages and groups stay.
- Tested on the dev card (Trixie 64-bit): install over the hand setup → no changes; uninstall → `config.txt` identical to the pre-AIY original, onboard
  `bcm2835 Headphones` + `vc4hdmi` after reboot; fresh install → reboot → `sndrpigooglevoi`, `make test_hw` and `make test_echo` ALL OK.
- **Freshly flashed card** (Trixie Lite 64-bit, 6.18.50): `make deploy` took 1 min 38 s. apt installed `python3-setuptools` with 10 dependencies
  (`python3-jaraco.*`, `python3-pkg-resources`, `python3-typeguard`…) and `libttspico-utils`/`libttspico0t64`/`libttspico-data`; everything else was
  preinstalled. After `make reboot`: `sndrpigooglevoi`, `make test_hw` and `make test_echo` ALL OK. **Not yet**: 32-bit.

## Status: Phase 4 examples and demo service (2026-10-21)

- **New `examples/voice/voice_echo_demo.py`**: push-to-talk echo with no network. Hold the button and speak; release to hear it back. LED: ON while recording,
  PULSE_QUICK while playing. Presses under `--min_seconds` (0.5) are ignored, and recordings stop at `--max_seconds` (15). `--greeting` speaks once at start.
  The release callback is set right after the press. The button thread ignores releases for 80 ms after a press (debounce), so a tap can't be missed.
- **`port/systemd/voice_echo_demo.service`** (`@USER@`, `@ECHO_ARGS@` filled in by install): `WorkingDirectory=~` for lgpio's `.lgd-nfy*`, `Restart=on-failure`.
  Installed **disabled** on the card. One start/stop came up clean ("Hold the button and speak…" in the journal).
- `port/tests/echo_demo_check.py` runs `echo_once` with a simulated button, playing to `null`. Press 2 s → 1.75 s recorded, played; tap 0.2 s → ignored;
  held → cut at 3 s. All pass.
- Upstream quirk found on the way (not changed): if a `Player` subclass's `play_*` raises, `Player.__exit__` → `join()` waits forever on `_started`, which hides the error.
- **Limitation**: each recording loses its first ~0.25 s (arecord start-up) and starts with the ~200 ms mic thump, so the very start of a word can be cut.
  A fix would keep one `Recorder` running with a short ring buffer. Not done; revisit if it's noticeable.
- Examples carried over unchanged: `button_led.py`, `voice/voice_recorder.py` (benefits from the WAV header fix), `aiy/voice/tts.py` CLI (checked with `--device null`).
  `voice_recorder.py` and `button_led.py` need button presses: **not run yet**.

## Status: Phase 3 Python library (2026-10-21)

`port/python/` is this repo's own copy. It holds only the upstream files that apply to the Voice HAT, copied from the snapshot in `docs/aiyprojects-raspbian/src`
(commit `964f07f5`): `aiy/{board,leds,cloudspeech}.py`, `aiy/voice/`, `examples/button_led.py` and `examples/voice/{voice_recorder,cloudspeech_demo}.py`.
Vision-kit's changes (`pins.py`, `_buzzer.py`, camera, streaming) are all in files the Voice HAT doesn't use, so nothing came from its copy.
`port/python.patch` (`port/make-patches.sh`) is the diff against upstream. Installed with `pip install --no-index -e` into `/opt/aiy/venv` (`--system-site-packages`).

- **New break, arecord 1.2.14 (Trixie): no WAV header on SIGTERM/SIGINT.** It exits with `pcm_read: read error: Interrupted system call` and leaves the
  placeholder sizes (data = 2147483648), even on `-D null`. Upstream `record_file` always stops arecord with `terminate()`, so every recorded WAV
  (e.g. `voice_recorder.py`) had a bogus header, and Python's `wave` raised `MemoryError`. Fix: `aiy.voice.audio._fix_wav_sizes()` rewrites the RIFF and
  `data` sizes from the file size after arecord exits. arecord still prints the `Interrupted system call` line (harmless). Not compared with Bookworm's 1.2.8.
  `record_file_async` callers who stop arecord themselves still get the bad header. **Open:** whether to fix that too.
- **P3 fixed**: `tts.say` runs `pico2wave` and `aplay` with argument lists (text with `"`, `$` or backticks works), and falls back to the default temp dir
  when `/run/user/<uid>` is missing.
- **P1 confirmed**: `Board()` picks `SingleColorLed` (no KTD202x). On/blink/pulse/off run through `python3-rpi-lgpio`. lgpio leaves `.lgd-nfy0` in the working directory.
- **P6**: `setup.py` needs only `gpiozero`; `google-cloud-speech` is an extra. **Lite Trixie lacks `python3-setuptools`**, which the offline editable install
  needs, so `install.sh` must apt-install it (vision-kit already does).
- **Mic start-up transient**: the first ~200 ms of every capture has a thump (−27 dBFS at ×4), then the floor is about −70 dBFS. It's probably the MEMS
  mics settling once the I2S clock starts. Harmless for speech; tests that measure level should skip the start.
- `port/tests/hardware_check.py`: everything passes silently on the card (LED class and states, a 2 s `record_file` with a sane level, playback path, `tts.say`,
  shell-character text). `--play` (speaker at 20 %) and `--button N` haven't been run yet.
- Not done: `aiy.cloudspeech` is still the upstream (pre-2.0 API) code (P4).

## Status: Phase 2 gate passed (2026-10-21)

On the Trixie card (`pi@voice-kit.local`, Pi 3 B, Raspberry Pi OS Lite 64-bit, kernel `6.18.50+rpt-rpi-v8`, Python 3.13.5):
- `config.txt`: comment out `dtparam=audio=on` and add `dtparam=i2s=on` + `dtoverlay=googlevoicehat-soundcard`. **No `i2s-mmap`.** After a reboot, card 0 is
  `sndrpigooglevoi`. The firmware logs `Loaded overlay 'googlevoicehat-soundcard'` and the same harmless `Failed to load HAT overlay` as on Bookworm (K4).
- `/etc/asound.conf` = `port/alsa/asound.conf`: named dmix/dsnoop on `hw:CARD=sndrpigooglevoi` (S32_LE/48 kHz/2 ch), `softvol "Master"`, `route` mic gain,
  `asym` default. Verified:
  - **dsnoop**: two recorders at once (raw dsnoop and `default`).
  - **dmix**: two `aplay` at once.
  - **softvol**: `Master` appears only after the first playback (A1, as expected). A speaker → mic loopback with a −20 dBFS 1 kHz tone read
    −3.8 / −19.7 / −24.6 dBFS RMS at 100/50/25 %, so the volume works. (At 100 % with the old ×30 gain, the loopback clipped.)
- **Mic gain is ×4 (+12 dB), not ×30.** With no gain, quiet late-night speech at a normal distance measured: room −76 dBFS (median of 100 ms RMS), loudest 10 % of speech −53 dBFS,
  peak −26.6 dBFS (`vendor/trixie/speech_raw.wav`). ×30 would clip that (about +3 dBFS). ×4 puts quiet speech at about −15 dBFS peak and normal speech at
  about −5 dBFS. **Open:** confirm with a normal-voice recording.
- **P1 PWM**: `RPi.GPIO` `GPIO.PWM(25, 100)` through `python3-rpi-lgpio 0.6` (preinstalled on Trixie) ran a 6 s pulse with no errors. Whether it looked smooth
  wasn't checked by eye. lgpio leaves `.lgd-nfy*` in the working directory (as in vision-kit).
- **P3**: `non-free` is enabled in the Trixie image. `libttspico-utils 1.0+git20130326-14.1` installs, and `pico2wave` renders 16 kHz mono (−3.7 dBFS peak).
- Not yet checked: the amp's click/pop at playback start (needs listening), and the button (needs a press).

## Summary

| # | Item | Break | Blocker? |
|---|---|---|---|
| K1 | Voice HAT codec + soundcard drivers | none: in-tree, built as modules in every Pi defconfig | No |
| K2 | `googlevoicehat-soundcard` overlay | none: unchanged in 6.12/6.18 | No |
| K3 | `dtoverlay=i2s-mmap` | the overlay no longer exists, so the line is a no-op | No, drop it |
| K4 | HAT EEPROM's embedded device tree | firmware rejects it (`not a valid FDT`) | No, `config.txt` loads the overlay explicitly |
| A1 | Volume and mic gain | the codec has no ALSA controls; needs `asound.conf` | No |
| A2 | Sharing the card (wyoming, AIY) | needs dmix/dsnoop to be the `default` | Only if the two must coexist |
| P1 | `aiy.board` on `RPi.GPIO` | works through the `python3-rpi-lgpio` shim | No (check PWM) |
| P2 | `aiy.voice.audio` (arecord/aplay) | none, apart from the ALSA `default` (A1) | No |
| P3 | `aiy.voice.tts` (pico2wave) | the package exists; the code has quoting and `/run/user` bugs | No, small fix |
| P4 | `aiy.cloudspeech` | written for `google-cloud-speech` < 2.0 (`speech.types`) | Optional feature |
| P5 | `aiy.assistant` + 4 Assistant demos | the service is shut down | Can't be ported (deferred: phase 7) |
| P6 | `setup.py` | lists picamera, the Assistant packages, RPi.GPIO | No, trim it |
| S1 | venv / PEP 668 | the same as vision-kit | No |

**Conclusion: no blockers.** Phase 2 is "flash, add three lines and `asound.conf`, and measure". It doesn't need a driver build.

## Kernel and boot

### K1: drivers (**H**, **B**)
- `sound/soc/bcm/googlevoicehat-codec.c` is the same file in `rpi-6.12.y` and `rpi-6.18.y`. Compared with `rpi-6.6.y` (what the card runs), the only
  change is the mechanical `platform_driver.remove` → `void`. The card driver is `rpi-simple-soundcard.c` (compatible `googlevoicehat,googlevoicehat-soundcard`).
- `CONFIG_SND_BCM2708_SOC_GOOGLEVOICEHAT_SOUNDCARD=m` and `CONFIG_SND_BCM2835_SOC_I2S=m` are set in `bcm2709_defconfig` (Pi 2/3, 32-bit),
  `bcm2711_defconfig` (64-bit) and `bcmrpi_defconfig` (Pi Zero/1) on both branches. So the Voice HAT also works on a Pi Zero W in principle (not a target).
- On the card: the modules `snd_soc_googlevoicehat_codec`, `snd_soc_rpi_simple_soundcard` and `snd_soc_bcm2835_i2s` load. The only log line is
  `property 'voicehat_sdmode_delay' not found default 5 mS` (expected: the overlay doesn't set it).

### K2: overlay (**H**, **B**)
- `googlevoicehat-soundcard-overlay.dts` has the same blob SHA (`1063f18985`) in 6.12 and 6.18, and the overlay README entry takes no params.
- Pins: I2S on GPIO 18–21 (`dtparam=i2s=on`), and the amp's **SD_MODE on GPIO 16** (`sdmode-gpios`). The driver drives it high 5 ms after playback
  starts, to avoid the pop. GPIO 16, 18–21 and the button/LED (23/25) must not be used by anything else.
- `config.txt` today: `dtparam=i2s=on` + `dtoverlay=googlevoicehat-soundcard`. The firmware log says `Loaded overlay 'googlevoicehat-soundcard'`.

### K3: `i2s-mmap` is gone (**H**, **B**)
- The 2017 `configure-driver.sh` added `dtoverlay=i2s-mmap`. The overlay doesn't exist in `rpi-6.12.y`/`rpi-6.18.y`, and isn't in the card's
  `/boot/firmware/overlays` on 6.6 either, but the card still has the line. The firmware skips it.
- MMAP access works without it: `arecord --dump-hw-params` lists `MMAP_INTERLEAVED` (**B**). `install.sh` must not add the line. Phase 2 confirms
  that dmix/dsnoop (which need mmap) work on a card without it.

### K4: HAT EEPROM (**B**)
- The EEPROM identifies the board (`Google AIY audioHAT Board v1`, Google, Inc., product 0x0001 v0x0001). The firmware reads it and then logs
  `dterror: not a valid FDT - err -9` / `Failed to load HAT overlay`. The embedded DT blob is too old to parse. It's harmless, because `config.txt`
  loads the overlay by name. **Consequence: `install.sh` must write the overlay line.** Auto-detection doesn't work for this HAT.
- `install.sh` can use `/proc/device-tree/hat/product` to check that it's running on a Voice HAT.

## Audio (ALSA)

### A1: volume and gain (**B**, **C**)
- `amixer -c0 contents` is empty. The hw format is S32_LE, 2 ch, 48 kHz (both directions, **B**; other rates and formats weren't dumped). The `plug` layer
  converts (wyoming records 16 kHz mono S16 that way).
- With no gain, a quiet room reads about −63 dBFS RMS / −36 dBFS peak per mic channel (**B**).
- 2017 `asound.conf` (**C**, `vendor/hepp-extract/hepp/etc/asound.conf`): `softvol` (control `Master`) over `dmix` for playback, and a `route` with
  ×30 (+29.5 dB) on both channels over `dsnoop` for capture, joined by `asym` as `pcm.!default`. Plan: install the same thing, minus the stray
  `options snd_rpi_googlemihat_soundcard index=0` line (modprobe syntax), and with `card sndrpigooglevoi` by name instead of card 0.
- The `Master` softvol control appears only after the first playback through it (hence the 2017 `alsa-init.service`). In phase 2, check whether a one-shot
  `aplay` of silence in `install.sh` is enough, now that there's no desktop volume applet.
- **?** whether ×30 clips speech at 30–50 cm. Measure speech peak/RMS in phase 2 and pick the gain from that (the ×30 may be too much for 32-bit dsnoop).

### A2: sharing with wyoming-satellite (**B**)
- wyoming records and plays on `plughw:CARD=sndrpigooglevoi,DEV=0`, which is exclusive, so while it runs nothing else can open the card.
- If coexisting is wanted (still undecided), point wyoming's `--mic-command`/`--snd-command` at `-D default` once A1's dsnoop/dmix is installed.
  For now `install.sh` leaves wyoming alone, and tests stop it and start it again.
- PipeWire/PulseAudio aren't installed on Lite (**B**: no packages). Plain ALSA is the design.

## Python library

Base: this repo's own copy of vision-kit's `port/python/` (already ported: venv layout, gpiozero 2 `pins.py`, `_buzzer.py`). Vision-kit changed
nothing in `board.py`, `leds.py`, `voice/` or `cloudspeech.py`, so the items below are new work.

### P1: `aiy.board` (**C**, **B**, PWM **?**)
- `Button` uses `RPi.GPIO` (`add_event_detect`-style polling thread). `SingleColorLed` uses `GPIO.PWM(25, 100)` for brightness and patterns.
  `Led = MultiColorLed if Leds.installed() else SingleColorLed`. `Leds.installed()` checks `/sys/class/leds/ktd202x:led1`, which doesn't exist on
  the Voice HAT, so it picks `SingleColorLed` (correct).
- The card has `python3-rpi-lgpio 0.6`, the RPi.GPIO API on lgpio (**B**/**D**). Vision-kit installs the same package and verified the button on GPIO 23
  through it. **?** `GPIO.PWM` through rpi-lgpio (software PWM in lgpio): check that LED blink/pulse patterns look right.
- `GPIO.setmode(GPIO.BCM)` + `GPIO.cleanup(channel)`: supported by the shim.

### P2: `aiy.voice.audio` (**C**)
- Only `arecord`/`aplay` subprocesses (`alsa-utils`, already installed), `wave` and threads. The default device is `default`, so it depends on A1 to get
  gain and shared access. No code change expected. **?** confirm `Recorder` chunking at 16 kHz mono S16 through `plug:micboost`.

### P3: `aiy.voice.tts` (**C**, **D**)
- `libttspico-utils` (`pico2wave`) is in Debian **non-free**. Bookworm `1.0+git20130326-13` and Trixie `-14.1`, both arm64/armhf/armel (**D**). The card's
  sources include `non-free` (**B**). Check on a fresh Trixie card that `non-free` is enabled in the Raspberry Pi OS image. If not, `install.sh` must add it,
  or fall back to `espeak-ng` (main; Bookworm 1.51, Trixie 1.52).
- Bugs to fix: (a) the command is built with `shell=True` and the text interpolated inside `"…"`, so text with `"`, `$` or backticks breaks (and is a shell
  injection). Use an argument list. (b) `RUN_DIR = /run/user/<uid>` doesn't exist for system services or non-login users. Fall back to `tempfile` defaults.

### P4: `aiy.cloudspeech` + `cloudspeech_demo.py` (**C**)
- Uses `speech.types.*` and `speech.types.RecognitionConfig.LINEAR16`, the API of `google-cloud-speech` < 2.0. Current versions (2.x) use `speech.RecognitionConfig`,
  `speech.RecognitionConfig.AudioEncoding.LINEAR16` and `speech.StreamingRecognizeRequest`. **Not in Debian:** it would be a pip install into the venv (with
  grpcio wheels; Debian has `python3-grpcio 1.51.1`, which might work with `--system-site-packages`).
- It needs a GCP service account at `~/cloud_speech.json`. Proposed: port the code to the 2.x API, behind an optional `install.sh --cloudspeech`, untested unless you
  provide a key. Not part of the default install.

### P5: `aiy.assistant` and the Assistant demos (**C**)
- `aiy/assistant/{library,grpc,auth_helpers,device_helpers}.py` and `assistant_library_demo.py`, `assistant_library_with_button_demo.py`,
  `assistant_library_with_local_commands_demo.py`, `assistant_grpc_demo.py` (+ `.service`) need `google-assistant-library` (an armv7 binary, never
  built for Python > 3.7 or arm64) or `google-assistant-grpc` (the Embedded Assistant API). Neither works today.
- Proposed: **don't install them.** Keep them out of `port/python/` and list them in Known gaps. Their replacement is phase 7 (deferred).

### P6: `setup.py` (**C**)
- Upstream `install_requires` lists `google-assistant-library`, `google-assistant-grpc`, `google-auth*`, `google-cloud-speech`, `picamera` and `RPi.GPIO`.
  Vision-kit already trimmed it to what apt provides (`--system-site-packages`, `pip install --no-index`). For voice: `gpiozero` only (RPi.GPIO from
  `python3-rpi-lgpio`), and `google-cloud-speech` as an extra.

### S1: system packages (**D**/**B**)
apt (Bookworm candidates on the card): `alsa-utils 1.2.8`, `python3-gpiozero 2.0.1`, `python3-lgpio 0.2.2`, `python3-rpi-lgpio 0.6`,
`libttspico-utils`, optionally `espeak-ng`. The venv goes at `/opt/aiy/venv` with `--system-site-packages`, as in vision-kit. Trixie repeats the check in phase 5.

## Examples to carry over

| Example | Needs | Expected |
|---|---|---|
| `examples/button_led.py` | P1 | works |
| `examples/voice/voice_recorder.py` | P1, P2, A1 | works |
| `examples/gpiozero/*` (button/LED subset) | P1 | works; skip the bonnet-only ones (KTD LED, PIN_A..D, buzzer) |
| `aiy/voice/tts.py` as a CLI | P3 | works after the fix |
| `examples/voice/cloudspeech_demo.py` | P4 | optional |
| `examples/voice/assistant_*` | P5 | not ported |

## Open (for phase 2)
- Mic gain: measure speech level and choose the `route` factor (A1).
- `Master` softvol initialisation without `alsa-init.service` (A1).
- dmix/dsnoop with no `i2s-mmap` (K3).
- `GPIO.PWM` LED patterns through rpi-lgpio (P1).
- Raspberry Pi OS **Trixie** image: whether `non-free` is enabled (P3), and whether `python3-rpi-lgpio` is still available.
