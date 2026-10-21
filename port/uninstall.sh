#!/bin/bash
# Removes what install.sh added. Apt packages, group memberships and the user's
# linger setting (from --ha-satellite) are left as they are.
#
#   sudo ./uninstall.sh
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
CONFIG_TXT=/boot/firmware/config.txt

systemctl disable --now voice_echo_demo.service aiy-voice-volume.service \
  linux-voice-assistant.service lva_bridge.service 2>/dev/null || true
rm -f /etc/systemd/system/voice_echo_demo.service /etc/systemd/system/aiy-voice-volume.service \
  /etc/systemd/system/linux-voice-assistant.service /etc/systemd/system/lva_bridge.service
systemctl daemon-reload

# PipeWire goes back to opening the sound cards itself at the next restart or reboot.
rm -f /etc/pipewire/pipewire.conf.d/51-aiy-voicehat.conf /etc/wireplumber/wireplumber.conf.d/51-aiy-voicehat.conf

# Includes the Linux Voice Assistant checkout and its venv.
rm -rf /opt/aiy

if [[ -f /etc/asound.conf.orig-aiy ]]; then
  mv /etc/asound.conf.orig-aiy /etc/asound.conf
elif grep -q 'AIY Voice HAT' /etc/asound.conf 2>/dev/null; then
  rm /etc/asound.conf
fi

# Remove the block install.sh appended, plus the unmarked lines from early hand setups,
# and turn the onboard audio back on.
sed -i '/^# >>> aiy-voice-kit$/,/^# <<< aiy-voice-kit$/d' "$CONFIG_TXT"
if grep -q '^dtoverlay=googlevoicehat-soundcard$' "$CONFIG_TXT"; then
  sed -i -e '/^dtoverlay=googlevoicehat-soundcard$/d' -e '/^dtparam=i2s=on$/d' "$CONFIG_TXT"
fi
sed -i 's/^#dtparam=audio=on  # aiy-voice-kit.*/dtparam=audio=on/' "$CONFIG_TXT"
grep -q '^dtparam=audio=on' "$CONFIG_TXT" || sed -i 's/^#dtparam=audio=on$/dtparam=audio=on/' "$CONFIG_TXT"
# install.sh's backup; a stale one would be kept by the next install's cp -n.
rm -f "$CONFIG_TXT.orig-aiy"

echo "Uninstalled. Reboot to switch back to the onboard audio: sudo reboot"
