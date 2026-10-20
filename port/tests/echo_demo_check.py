#!/usr/bin/env python3
"""Runs voice_echo_demo.echo_once with a simulated button, playing to the "null" device.

Covers a normal press (recorded and played back), a tap shorter than --min_seconds
(ignored), and a press held past --max_seconds (cut off). Silent; no button needed.
"""
import os
import sys
import tempfile
import threading
import time

sys.path.insert(0, '/opt/aiy/python/src/examples/voice')
import voice_echo_demo  # noqa: E402
from aiy.board import Led  # noqa: E402


class FakeButton:
    """Presses at once, then releases after `hold` seconds (None: never)."""

    def __init__(self, hold):
        self.hold = hold
        self.when_released = None

    def wait_for_press(self, timeout=None):
        if self.hold is not None:
            threading.Timer(self.hold, lambda: self.when_released and self.when_released()).start()
        return True


class FakeLed:
    def __init__(self):
        self.states = []

    def _set(self, state):
        self.states.append(state)

    state = property(None, _set)


def run(name, hold, expect_min, expect_max, expect_states):
    led = FakeLed()
    with tempfile.TemporaryDirectory() as tmp:
        start = time.monotonic()
        seconds = voice_echo_demo.echo_once(FakeButton(hold), led, os.path.join(tmp, 'e.wav'),
                                            min_seconds=0.5, max_seconds=3, device='null')
        took = time.monotonic() - start
    ok = expect_min <= seconds <= expect_max and led.states == expect_states
    names = {Led.ON: 'ON', Led.PULSE_QUICK: 'PULSE_QUICK', Led.OFF: 'OFF'}
    print('%-30s %s recorded %.2f s, took %.2f s, LED %s' % (
        name, 'OK  ' if ok else 'FAIL', seconds, took,
        ' > '.join(names.get(s, '?') for s in led.states)), flush=True)
    return ok


def main():
    on, pulse, off = Led.ON, Led.PULSE_QUICK, Led.OFF
    results = [
        run('press 2 s', 2.0, 1.4, 2.1, [on, pulse, off]),
        run('tap 0.2 s (ignored)', 0.2, 0, 0, [on, off]),
        run('held past max_seconds=3', None, 2.4, 3.1, [on, pulse, off]),
    ]
    print('ALL OK' if all(results) else 'SOME CHECKS FAILED')
    return 0 if all(results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
