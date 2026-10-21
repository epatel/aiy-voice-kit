# alsa-audio

The Voice HAT's ALSA setup (`port/alsa/asound.conf` → `/etc/asound.conf`): device names, mic gain, volume, sharing, and the measured levels behind the choices.

## Facts about the card

- Name `sndrpigooglevoi`. Address it by name (`hw:CARD=sndrpigooglevoi,DEV=0`), not by index; the config already does.
- The hardware does only **S32_LE, 2 channels, 48 kHz**, in both directions. Anything else goes through `plug`.
- **No mixer controls at all**, so `amixer` shows nothing until the softvol below has been used once.

## What asound.conf builds

| PCM | Purpose |
|---|---|
| `voicehat_dmix` (ipc_key 5611) | shared playback, so several programs can play at once |
| `voicehat_dsnoop` (ipc_key 5612) | shared capture, so several programs can record at once |
| `softvol` | `Master` volume control over dmix |
| `micboost` | `route` with ×4 on both channels over dsnoop |
| `pcm.!default` | `asym`: `plug:softvol` for playback, `plug:micboost` for capture |

`Master` **appears only after the first playback through `default`**, so `amixer sset Master` fails on a fresh install ("Unable to find simple control",
seen with `make test_play` on the freshly flashed card). `aiy-voice-volume.service` (installed and enabled by install.sh, like Google's 2017 `alsa-init.service`)
fixes it: at boot, after `alsa-restore`, if `Master` is missing it plays 1 s of zeros through `default` and sets 30 %. Once `Master` exists, `alsa-restore` stores it
at shutdown and restores it at boot, so a user's volume survives reboots (checked: 25 % before → 25 % after).

## Mic gain: why ×4

Measured on the Trixie card with no gain (dsnoop raw): room floor about −76 dBFS (median of 100 ms RMS windows); quiet late-night speech had its loudest 10 %
at −53 dBFS and peaked at −26.6 dBFS. Google's ×30 (+29.5 dB) would put that quiet speech at about +3 dBFS, which clips; normal speech is about 10 dB louder still.
×4 (+12 dB) gives quiet speech about −15 dBFS peak and normal speech about −5 dBFS. **Not yet confirmed with normal-voice speech.** Change both `ttable` entries together.

## Known behaviour

- **The first ~200 ms of every capture is a thump** (about −27 dBFS at ×4), then the floor is about −70 dBFS. It's probably the mics settling when the I2S clock starts.
  Skip the start in any level measurement.
- `arecord` takes about 0.25 s to start delivering through the plugin chain.
- `dmix`/`dsnoop` need mmap access. It works on 6.18 without the old `i2s-mmap` overlay, which no longer exists.
- A program that opens `plughw:`/`hw:` directly takes the card exclusively and blocks everyone else. On the old Bookworm card `wyoming-satellite` does
  this; pointing it at `-D default` would let it share.

## Quick checks

`aplay -l` should list card 0 `sndrpigooglevoi`. `amixer sget Master` works after one playback.
`python3 port/tests/audio_levels.py file.wav` prints peak/RMS per channel.
