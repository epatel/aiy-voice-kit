SHELL := bash

# The Pi to deploy to and test on, e.g. make test_hw HOST=pi@192.168.68.74
HOST ?= pi@voice-kit.local
# Extra install.sh options for deploy, e.g. ARGS=--echo-service
ARGS ?=
# Speaker volume (softvol Master) for the targets that make sound
VOLUME ?= 20%
TEXT ?= Hello from the Voice Kit

PY := /opt/aiy/venv/bin/python
# Run a test on the Pi with the echo demo stopped (it holds the button and LED),
# and start it again afterwards, even when the test fails, if it was running.
ON_PI = ssh -o BatchMode=yes $(HOST) 'was=$$(systemctl is-active voice_echo_demo); [ "$$was" = active ] && sudo systemctl stop voice_echo_demo; cd ~; $(1); rc=$$?; [ "$$was" = active ] && sudo systemctl start voice_echo_demo; exit $$rc'

info: menu select

menu:
	echo "1 make deploy               - install/update the Pi (HOST=$(HOST), ARGS=$(ARGS))"
	echo "2 make reboot               - reboot the Pi"
	echo "3 make status               - sound card, config.txt, library and echo service on the Pi"
	echo "4 make test_hw              - LED, 2 s recording, playback + TTS paths (silent)"
	echo "5 make test_echo            - echo demo logic with a simulated button (silent)"
	echo "6 make test_play            - test_hw through the speaker at 20% (makes sound)"
	echo "7 make test_button          - wait 15 s for an arcade button press"
	echo "8 make say                  - speak TEXT at VOLUME (makes sound)"
	echo "9 make patches              - regenerate port/python.patch"
	echo "10 make check_docs          - check CLAUDE.md, cards and setup record"
	echo "11 make uninstall           - remove everything install.sh added from the Pi"
	echo "12 make update_phony        - update .PHONY in Makefile"

select:
	read -p ">>> " P ; "$(MAKE)" --no-print-directory menu | grep "^$$P " | cut -d ' ' -f2-3 | bash

.SILENT:

.PHONY: info menu select deploy reboot status sync_tests test_hw test_echo test_play test_button say patches check_docs uninstall update_phony 

deploy:
	port/deploy.sh $(HOST) $(ARGS)

reboot:
	ssh $(HOST) sudo reboot || true

status:
	ssh -o BatchMode=yes $(HOST) 'uname -r; aplay -l | grep -o "card .*sndrpigooglevoi.*" || echo "Voice HAT card: missing"; grep -E "^#?dtparam=(audio|i2s)|^dtoverlay=googlevoicehat" /boot/firmware/config.txt; $(PY) -c "import aiy.board, aiy.voice.audio; print(\"aiy library: ok\")"; echo "voice_echo_demo: $$(systemctl is-enabled voice_echo_demo) $$(systemctl is-active voice_echo_demo)"'

sync_tests:
	rsync -a port/tests/ $(HOST):voice-kit-port/tests/

test_hw: sync_tests
	$(call ON_PI,$(PY) voice-kit-port/tests/hardware_check.py)

test_echo: sync_tests
	$(call ON_PI,$(PY) voice-kit-port/tests/echo_demo_check.py)

test_play: sync_tests
	$(call ON_PI,$(PY) voice-kit-port/tests/hardware_check.py --play)

test_button: sync_tests
	$(call ON_PI,$(PY) voice-kit-port/tests/hardware_check.py --button 15)

say:
	ssh -o BatchMode=yes $(HOST) 'amixer -q sset Master $(VOLUME) && cd ~ && $(PY) -m aiy.voice.tts "$(TEXT)"'

patches:
	port/make-patches.sh

check_docs:
	CHECK=$$(mktemp -d)/check-agent-docs.py; curl -fsSL https://ai.memention.net/cards/check-agent-docs.py -o "$$CHECK" && python3 -I "$$CHECK" .

uninstall:
	ssh -t $(HOST) 'cd voice-kit-port && sudo ./uninstall.sh'

update_phony:
	echo "##### Updating .PHONY targets #####"
	targets=$$(grep -E '^[a-zA-Z_][a-zA-Z0-9_-]*:' Makefile | grep -v '=' | cut -d: -f1 | tr '\n' ' '); \
	sed -i.bak "s/^\.PHONY:.*/.PHONY: $$targets/" Makefile && \
	echo "Updated .PHONY: $$targets" && \
	rm -f Makefile.bak
