# trixie-only

Decision (2026-10-21): the port targets Raspberry Pi OS **Trixie** only, 64-bit first. Bookworm was skipped as a target.

## The choice

Test and support Raspberry Pi OS Lite Trixie (kernel 6.18, Python 3.13) on a Pi 3 B, 64-bit (`rpi-v8`) first and 32-bit (`v7`) later if wanted.

## Alternatives considered

- Bookworm and Trixie, as the sibling vision-kit port does.
- Bookworm only (what the old `lemic` card already runs).

## Why this won

- Every piece the port needs is identical or present on Trixie. The Voice HAT codec driver is the same file in rpi-6.12.y and rpi-6.18.y (6.6 differed only by
  a `remove()` signature), and the overlay blob is identical. `CONFIG_SND_BCM2708_SOC_GOOGLEVOICEHAT_SOUNDCARD=m` is in every Pi defconfig.
  `python3-rpi-lgpio`, `python3-lgpio`, `python3-gpiozero` and `libttspico-utils` exist for arm64 and armhf.
- There are no out-of-tree drivers here, so the main reason to test several kernels (DKMS builds) doesn't apply.
- Testing one OS halves the device testing.

## When to revisit

Someone needs it on Bookworm, or on a Pi Zero W (`bcmrpi`, armhf). Bookworm will probably work, since `lemic` runs the same audio stack on 6.6, but check
`python3-setuptools`, the arecord version (the WAV header fix is harmless either way) and the `non-free` component.
