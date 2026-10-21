# testing-on-device

Which SD card is in the Pi, how to reach it, the test scripts in `port/tests/`, and the shell traps that cost time in earlier sessions.

## The cards (one Pi 3 B, swap SD cards)

| Card | Host | Kernel / Python | State |
|---|---|---|---|
| Trixie Lite 64-bit (development) | `pi@voice-kit.local` (DHCP gave it `192.168.68.74`) | 6.18.50 / 3.13.5 | Reflashed 2026-10-21 and set up with `make deploy` alone (Imager: SSH key, passwordless sudo). Echo service disabled |
| Bookworm 64-bit `lemic` (baseline only) | `pi@192.168.68.74` when it's in the Pi (was `192.168.0.104`) | 6.6.51 / 3.11.2 | Runs `wyoming-satellite` (a Home Assistant voice satellite) that holds the mic. **Don't change it**; stop wyoming only briefly and start it again |

The Pi keeps its IP across cards, so ssh to the IP warns that the host key changed whenever the other card is in. Check `hostname` / `uname -r` before trusting a result.
SSH key auth works with `-o BatchMode=yes`. Accept a fresh card's host key with `-o StrictHostKeyChecking=accept-new`.

## Test scripts (copy `port/tests/` to `~/voice-kit-port/tests/`, run with `/opt/aiy/venv/bin/python` from `~`)

| Script | Checks | Needs |
|---|---|---|
| `hardware_check.py` | LED class + states, a 2 s `record_file` with a sane level, playback path, `tts.say` (also with shell characters) | silent by default |
| `hardware_check.py --play` | the same, through the speaker at `Master` 20 % | someone listening (and it not being night) |
| `hardware_check.py --button 15` | an arcade button press within 15 s | someone at the kit |
| `echo_demo_check.py` | the echo demo's logic with a simulated button | silent, demo service stopped |
| `audio_levels.py a.wav …` | peak/RMS dBFS per channel | nothing |

From the Mac, `make test_hw`, `test_echo`, `test_play` and `test_button` copy the tests, stop the echo service if it's running, run the script and start the
service again. `make status` shows the sound card, the config.txt lines, the library import and the service state.

Ask before making any sound. The user has asked for low volume late in the evening (use `amixer sset Master 15%`).

## Traps

- **`pkill -f PATTERN` inside `ssh host '…'` kills the ssh shell itself**, because its command line contains the pattern. The same goes for `ps | grep -c PATTERN`
  counting itself. Use a script file on the Pi, or match on something not in the command.
- **Piping test output through `grep` buffers it until exit**, so a hung test shows nothing. Write to a log file and use
  `timeout -s ABRT N python -X faulthandler …` to get a stack dump.
- `arecord` prints `read error: Interrupted system call` whenever it's stopped by a signal. That's harmless (see `aiy.voice.audio._fix_wav_sizes`).
- `/tmp` on the Pi is cleared at reboot.
