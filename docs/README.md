# docs/: reference material

Treat everything here as read-only reference: don't edit vendored files; re-fetch rather than patch. Port changes go in `port/`.

## Vendored sources

| Path | What | Upstream |
|---|---|---|
| [`aiyprojects-raspbian/`](aiyprojects-raspbian/) | Google's AIY repo, snapshot taken 2026-10-20 (commit in `COMMIT`; last upstream change 2021-04-15). The upstream that `port/python.patch` diffs against. Apache-2.0 (`LICENSE`); its kernel drivers are GPL-2.0 | <https://github.com/google/aiyprojects-raspbian> |

### Most useful files for the Voice Kit v1

| File | Why |
|---|---|
| [`HACKING.md`](aiyprojects-raspbian/HACKING.md) | How the stock stack was installed on plain Raspbian: packages, `config.txt` lines |
| [`CHANGES.md`](aiyprojects-raspbian/CHANGES.md) | Image release history |
| [`docs/voice.md`](aiyprojects-raspbian/docs/voice.md) | Voice Kit overview and the Python modules |
| [`docs/aiy.voice.audio.rst`](aiyprojects-raspbian/docs/aiy.voice.audio.rst), [`aiy.voice.tts.rst`](aiyprojects-raspbian/docs/aiy.voice.tts.rst), [`aiy.board.rst`](aiyprojects-raspbian/docs/aiy.board.rst) | API docs for the ported modules |
| [`src/aiy/voice/`](aiyprojects-raspbian/src/aiy/voice/), [`src/aiy/board.py`](aiyprojects-raspbian/src/aiy/board.py) | Upstream of `port/python/src/aiy/` |
| [`src/aiy/assistant/`](aiyprojects-raspbian/src/aiy/assistant/), [`src/examples/voice/`](aiyprojects-raspbian/src/examples/voice/) | The Assistant and Cloud Speech demos (not ported; the Assistant service is shut down) |
| [`checkpoints/check_audio.py`](aiyprojects-raspbian/checkpoints/check_audio.py) | Google's original audio self-test |
| [`schematics/voice_hat/`](aiyprojects-raspbian/schematics/voice_hat/) | Voice HAT and mic board schematics |
| [`drivers/sound/`](aiyprojects-raspbian/drivers/sound/), [`drivers/overlays/voice/`](aiyprojects-raspbian/drivers/overlays/voice/) | **Voice Bonnet (v2)** driver and overlay; not used by the v1 Voice HAT, whose driver is in the Raspberry Pi kernel |

## Links only

- [Voice Kit v1 guide](https://aiyprojects.withgoogle.com/voice-v1/): assembly and usage. No redistribution license found, so it isn't copied here.
- Voice HAT driver in the Raspberry Pi kernel: `sound/soc/bcm/googlevoicehat-codec.c` and `arch/arm/boot/dts/overlays/googlevoicehat-soundcard-overlay.dts`
  in <https://github.com/raspberrypi/linux>.
