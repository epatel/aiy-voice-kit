#!/bin/bash
# Installs the AIY Voice Kit v1 (Voice HAT) stack on Raspberry Pi OS Lite Trixie.
#
#   sudo ./install.sh [options]
#
# Run from the port/ directory. Safe to re-run. The Voice HAT drivers are in the
# Raspberry Pi kernel, so this only configures the overlay, ALSA, the Python
# library, and optionally the echo demo or a Home Assistant voice satellite.
#
# Options:
#   --user NAME          user for the services and GPIO/audio access (default: $SUDO_USER or pi)
#   --echo-service       enable the push-to-talk echo demo at boot
#   --no-echo-service    disable it (without either, a re-run keeps its current state; new installs: disabled)
#   --echo-args "ARGS"   extra voice_echo_demo.py options for the service, e.g. "--greeting Hello"
#   --ha-satellite       install and enable a Home Assistant voice satellite: Linux Voice Assistant
#                        over PipeWire, with the button and LED (lva_bridge). Downloads LVA from GitHub
#                        and its Python packages from PyPI; the first install takes ~10 minutes
#   --no-ha-satellite    disable it (without either, a re-run keeps its current state)
#   --ha-name NAME       satellite name shown in Home Assistant: letters, digits, hyphens
#                        (default: the name from the last install, else the hostname)
#
# The echo demo and the satellite both use the button and LED, so only one can be enabled.
set -euo pipefail

# Linux Voice Assistant (successor of wyoming-satellite), pinned to a tested commit.
LVA_REPO=https://github.com/OHF-Voice/linux-voice-assistant.git
LVA_COMMIT=b49fd8dc6534111c12d08b18acbfd1135dc1b082
LVA_DIR=/opt/aiy/linux-voice-assistant
LVA_WAKE_MODEL=okay_nabu

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-pi}"
ECHO_SERVICE=""
ECHO_ARGS=""
HA_SATELLITE=""
HA_NAME=""

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) TARGET_USER="$2"; shift 2 ;;
    --echo-service) ECHO_SERVICE=1; shift ;;
    --no-echo-service) ECHO_SERVICE=0; shift ;;
    --echo-args) ECHO_ARGS="$2"; shift 2 ;;
    --ha-satellite) HA_SATELLITE=1; shift ;;
    --no-ha-satellite) HA_SATELLITE=0; shift ;;
    --ha-name) HA_NAME="$2"; shift 2 ;;
    -h|--help) sed -n '/^set -e/q;2,$p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "run with sudo"
id "$TARGET_USER" >/dev/null 2>&1 || die "user $TARGET_USER does not exist"
[[ -f "$SRC_DIR/alsa/asound.conf" && -d "$SRC_DIR/python/src/aiy" ]] || die "run from the port/ directory"
TARGET_UID="$(id -u "$TARGET_USER")"

# Without an option, keep what's enabled now.
if [[ -z "$HA_SATELLITE" ]]; then
  if systemctl is-enabled --quiet linux-voice-assistant 2>/dev/null; then HA_SATELLITE=1; else HA_SATELLITE=0; fi
fi
if [[ -z "$ECHO_SERVICE" ]]; then
  if systemctl is-enabled --quiet voice_echo_demo 2>/dev/null; then ECHO_SERVICE=1; else ECHO_SERVICE=0; fi
fi
# Keep the satellite's name on a re-run unless --ha-name was given.
LVA_UNIT=/etc/systemd/system/linux-voice-assistant.service
if [[ -z "$HA_NAME" && -f "$LVA_UNIT" ]]; then
  HA_NAME="$(sed -n 's#^ExecStart=.* --name \([^ ]*\).*#\1#p' "$LVA_UNIT")"
fi
HA_NAME="${HA_NAME:-$(hostname)}"
[[ "$HA_NAME" =~ ^[A-Za-z0-9-]+$ ]] || die "--ha-name: use letters, digits and hyphens only"
if [[ $HA_SATELLITE -eq 1 && $ECHO_SERVICE -eq 1 ]]; then
  die "the echo demo and the HA satellite both use the button and LED: add --no-echo-service or --no-ha-satellite"
fi

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

if [[ $HA_SATELLITE -eq 1 ]]; then
  log "Installing the Home Assistant voice satellite (Linux Voice Assistant)"
  apt-get install -y --no-install-recommends \
    pipewire wireplumber pipewire-pulse pulseaudio-utils \
    git build-essential python3-dev libmpv-dev avahi-utils python3-websockets
  # PipeWire uses the Voice HAT through /etc/asound.conf, not directly.
  install -d /etc/pipewire/pipewire.conf.d /etc/wireplumber/wireplumber.conf.d
  install -m 644 "$SRC_DIR/pipewire/pipewire-51-aiy-voicehat.conf" /etc/pipewire/pipewire.conf.d/51-aiy-voicehat.conf
  install -m 644 "$SRC_DIR/pipewire/wireplumber-51-aiy-voicehat.conf" /etc/wireplumber/wireplumber.conf.d/51-aiy-voicehat.conf
  # PipeWire runs in the user's session; linger starts it at boot without a login.
  loginctl enable-linger "$TARGET_USER"
  systemctl start "user@$TARGET_UID.service"
  systemctl --machine="$TARGET_USER@" --user restart pipewire pipewire-pulse wireplumber

  as_user() { runuser -u "$TARGET_USER" -- "$@"; }
  if [[ ! -d "$LVA_DIR/.git" ]]; then
    install -d -o "$TARGET_USER" -g "$TARGET_USER" "$LVA_DIR"
    as_user git clone -q "$LVA_REPO" "$LVA_DIR"
  fi
  NEED_SETUP=0
  if [[ "$(as_user git -C "$LVA_DIR" rev-parse HEAD)" != "$LVA_COMMIT" ]]; then
    as_user git -C "$LVA_DIR" fetch -q origin
    as_user git -C "$LVA_DIR" checkout -q "$LVA_COMMIT"
    NEED_SETUP=1
  fi
  [[ -x "$LVA_DIR/.venv/bin/python" ]] || NEED_SETUP=1
  if [[ $NEED_SETUP -eq 1 ]]; then
    echo "Running LVA's script/setup (Python packages from PyPI into $LVA_DIR/.venv; ~10 minutes on a Pi 3)"
    (cd "$LVA_DIR" && as_user env HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)" ./script/setup > "$LVA_DIR/setup.log" 2>&1) \
      || die "LVA setup failed, see $LVA_DIR/setup.log"
  fi

  sed -e "s|@USER@|$TARGET_USER|g" -e "s|@UID@|$TARGET_UID|g" -e "s|@LVA_DIR@|$LVA_DIR|g" \
      -e "s|@NAME@|$HA_NAME|" -e "s|@WAKE_MODEL@|$LVA_WAKE_MODEL|" \
    "$SRC_DIR/systemd/linux-voice-assistant.service" > "$LVA_UNIT"
  sed -e "s|@USER@|$TARGET_USER|" "$SRC_DIR/systemd/lva_bridge.service" > /etc/systemd/system/lva_bridge.service
  systemctl daemon-reload
  systemctl enable linux-voice-assistant.service lva_bridge.service
  if [[ $REBOOT_NEEDED -eq 0 ]]; then systemctl restart linux-voice-assistant.service lva_bridge.service; fi
elif [[ -f "$LVA_UNIT" ]]; then
  log "Disabling the Home Assistant voice satellite"
  systemctl disable --now linux-voice-assistant.service lva_bridge.service 2>/dev/null || true
fi

if ! aplay -l 2>/dev/null | grep -q sndrpigooglevoi; then
  REBOOT_NEEDED=1
fi

log "Done"
cat <<EOF
  Sound card: $(aplay -l 2>/dev/null | grep -q sndrpigooglevoi && echo sndrpigooglevoi || echo "not up yet (reboot)")
  Python:     /opt/aiy/venv/bin/python  (examples in /opt/aiy/python/src/examples/voice)
  Service:    voice_echo_demo $( [[ $ECHO_SERVICE -eq 1 ]] && echo enabled || echo disabled )${ECHO_ARGS:+ ($ECHO_ARGS)}
  Satellite:  $( [[ $HA_SATELLITE -eq 1 ]] && echo "linux-voice-assistant + lva_bridge enabled, name $HA_NAME (Home Assistant finds it as an ESPHome device)" || echo disabled )
EOF
if [[ $REBOOT_NEEDED -eq 1 ]]; then
  echo "  Reboot required (config.txt changed or the Voice HAT card isn't up yet): sudo reboot"
fi
