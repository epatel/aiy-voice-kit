#!/bin/bash
# Installs the AIY Voice Kit v1 (Voice HAT) stack on Raspberry Pi OS Lite Trixie.
#
#   sudo ./install.sh [options]
#
# Run from the port/ directory. Safe to re-run. The Voice HAT drivers are in the
# Raspberry Pi kernel, so this only configures the overlay, ALSA, the Python
# library and the optional echo demo service.
#
# Options:
#   --user NAME          user for the echo demo service and GPIO/audio access (default: $SUDO_USER or pi)
#   --echo-service       enable the push-to-talk echo demo at boot
#   --no-echo-service    disable it (without either, a re-run keeps its current state; new installs: disabled)
#   --echo-args "ARGS"   extra voice_echo_demo.py options for the service, e.g. "--greeting Hello"
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-pi}"
ECHO_SERVICE=""
ECHO_ARGS=""

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) TARGET_USER="$2"; shift 2 ;;
    --echo-service) ECHO_SERVICE=1; shift ;;
    --no-echo-service) ECHO_SERVICE=0; shift ;;
    --echo-args) ECHO_ARGS="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "run with sudo"
id "$TARGET_USER" >/dev/null 2>&1 || die "user $TARGET_USER does not exist"
[[ -f "$SRC_DIR/alsa/asound.conf" && -d "$SRC_DIR/python/src/aiy" ]] || die "run from the port/ directory"

# Read os-release in a subshell: it defines VERSION and friends.
OS_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
if [[ "$OS_CODENAME" != trixie ]]; then
  echo "warning: tested on Raspberry Pi OS Trixie only, this is $(. /etc/os-release && echo "${PRETTY_NAME:-unknown}"); continuing"
fi
if ! tr -d '\0' < /proc/device-tree/hat/product 2>/dev/null | grep -qi audioHAT; then
  echo "warning: no Voice HAT found in /proc/device-tree/hat; continuing anyway"
fi
CONFIG_TXT=/boot/firmware/config.txt
REBOOT_NEEDED=0

log "Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
  alsa-utils python3-venv python3-setuptools \
  python3-gpiozero python3-lgpio python3-rpi-lgpio
# pico2wave is in Debian non-free (enabled in Raspberry Pi OS); only aiy.voice.tts needs it.
apt-get install -y --no-install-recommends libttspico-utils \
  || echo "warning: libttspico-utils not installed (enable non-free); aiy.voice.tts won't work"
for g in audio gpio; do
  if getent group "$g" >/dev/null; then usermod -aG "$g" "$TARGET_USER"; fi
done

log "Configuring $CONFIG_TXT"
# The HAT EEPROM's device tree is rejected by the firmware, so the overlay must be named here.
cp -n "$CONFIG_TXT" "$CONFIG_TXT.orig-aiy" || true
if grep -q '^dtparam=audio=on' "$CONFIG_TXT"; then
  sed -i 's/^dtparam=audio=on.*/#dtparam=audio=on  # aiy-voice-kit: the Voice HAT replaces the onboard audio/' "$CONFIG_TXT"
  REBOOT_NEEDED=1
fi
if ! grep -q '^dtoverlay=googlevoicehat-soundcard' "$CONFIG_TXT"; then
  printf '\n# >>> aiy-voice-kit\n[all]\ndtparam=i2s=on\ndtoverlay=googlevoicehat-soundcard\n# <<< aiy-voice-kit\n' >> "$CONFIG_TXT"
  REBOOT_NEEDED=1
fi

log "Installing /etc/asound.conf"
if [[ -f /etc/asound.conf ]] && ! cmp -s /etc/asound.conf "$SRC_DIR/alsa/asound.conf" \
   && ! grep -q 'AIY Voice HAT' /etc/asound.conf; then
  cp -n /etc/asound.conf /etc/asound.conf.orig-aiy
fi
install -m 644 "$SRC_DIR/alsa/asound.conf" /etc/asound.conf
# The Master control only exists after the first playback; this service creates it at boot when it's missing.
# %% is systemd's escape for a literal %.
sed -e "s|@VOLUME@|30%%|" "$SRC_DIR/systemd/aiy-voice-volume.service" > /etc/systemd/system/aiy-voice-volume.service
systemctl daemon-reload
systemctl enable aiy-voice-volume.service
if aplay -l 2>/dev/null | grep -q sndrpigooglevoi; then
  systemctl restart aiy-voice-volume.service
fi

log "Installing the Python library into /opt/aiy/venv"
install -d /opt/aiy/python
(cd "$SRC_DIR/python" && tar --exclude=__pycache__ --exclude='*.egg-info' -cf - .) | tar -xf - -C /opt/aiy/python
[[ -d /opt/aiy/venv ]] || python3 -m venv --system-site-packages /opt/aiy/venv
# Offline: every dependency comes from apt through --system-site-packages.
/opt/aiy/venv/bin/pip install --quiet --no-index --no-build-isolation -e /opt/aiy/python
/opt/aiy/venv/bin/python -c 'import aiy.board, aiy.voice.audio, aiy.voice.tts' \
  || die "Python library import check failed"

log "Installing the echo demo service"
UNIT=/etc/systemd/system/voice_echo_demo.service
if [[ -z "$ECHO_SERVICE" ]]; then
  if systemctl is-enabled --quiet voice_echo_demo 2>/dev/null; then ECHO_SERVICE=1; else ECHO_SERVICE=0; fi
fi
# Keep the service's arguments on a re-run unless --echo-args was given.
if [[ -z "$ECHO_ARGS" && -f "$UNIT" ]]; then
  ECHO_ARGS="$(sed -n 's#^ExecStart=.*voice_echo_demo\.py *##p' "$UNIT")"
fi
ESCAPED_ARGS="$(printf '%s' "$ECHO_ARGS" | sed 's/[\\&|]/\\&/g')"
sed -e "s|@USER@|$TARGET_USER|" -e "s|@ECHO_ARGS@|$ESCAPED_ARGS|" \
  "$SRC_DIR/systemd/voice_echo_demo.service" > "$UNIT"
systemctl daemon-reload
if [[ $ECHO_SERVICE -eq 1 ]]; then
  systemctl enable voice_echo_demo.service
  # Pick up the new code now, unless the sound card only appears after a reboot.
  if [[ $REBOOT_NEEDED -eq 0 ]]; then systemctl restart voice_echo_demo.service; fi
else
  systemctl disable --now voice_echo_demo.service 2>/dev/null || true
fi

if ! aplay -l 2>/dev/null | grep -q sndrpigooglevoi; then
  REBOOT_NEEDED=1
fi

log "Done"
cat <<EOF
  Sound card: $(aplay -l 2>/dev/null | grep -q sndrpigooglevoi && echo sndrpigooglevoi || echo "not up yet (reboot)")
  Python:     /opt/aiy/venv/bin/python  (examples in /opt/aiy/python/src/examples/voice)
  Service:    voice_echo_demo $( [[ $ECHO_SERVICE -eq 1 ]] && echo enabled || echo disabled )${ECHO_ARGS:+ ($ECHO_ARGS)}
EOF
if [[ $REBOOT_NEEDED -eq 1 ]]; then
  echo "  Reboot required (config.txt changed or the Voice HAT card isn't up yet): sudo reboot"
fi
