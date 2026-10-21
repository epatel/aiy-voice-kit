# echo-demo

The push-to-talk echo demo (`port/python/src/examples/voice/voice_echo_demo.py`) and its boot service (`port/systemd/voice_echo_demo.service`).

## Flow

1. `button.wait_for_press()`.
2. **Immediately** set `button.when_released = released.set`. `aiy.board.Button` polls every 50 ms and ignores releases for 80 ms after a press
   (debounce), so setting the callback right away can't miss even a quick tap. `wait_for_release()` after starting arecord could miss it, and then the recording would
   run until the *next* release.
3. LED `ON`, then `record_file(16 kHz mono S16, wav, wait=released.wait(max_seconds))` on ALSA `default`.
4. If it's shorter than `--min_seconds` (0.5), LED `OFF` and ignore it. Otherwise LED `PULSE_QUICK`, play with `FilePlayer().play_wav(device=--device)`, then LED `OFF`.

Options: `--min_seconds`, `--max_seconds` (15), `--greeting TEXT` (said once at start via pico2wave), `--device` (playback; `null` for silent tests).
`echo_once(button, led, filename, min_seconds, max_seconds, device)` is the testable unit.

## Limitations

- Each recording loses its first ~0.25 s (arecord start-up) and begins with the ~200 ms mic thump, so the start of the first word can be cut. A fix would keep one
  `Recorder` running with a short ring buffer.
- It holds the button and LED GPIOs, so stop it before other tests that use them.

## Service

`voice_echo_demo.service`: `User=@USER@`, `WorkingDirectory=~` (lgpio writes `.lgd-nfy*` there), `Restart=on-failure`, and `ExecStart` = venv Python + the demo +
`@ECHO_ARGS@`. The placeholders are filled when it's installed (`sed`). Installed **disabled** on the Trixie card. Check it with
`sudo systemctl start voice_echo_demo` and `journalctl -u voice_echo_demo -o cat`, which should say "Hold the button and speak…".

## Tests

`port/tests/echo_demo_check.py` runs `echo_once` with a simulated button and plays to `null`. Expected results: a 2 s press records ~1.75 s and plays it (LED ON > PULSE_QUICK > OFF);
a 0.2 s tap is ignored (ON > OFF); a held press is cut at 3 s. The real button and speaker haven't been tried yet.
