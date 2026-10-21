#!/usr/bin/env python3
"""Runs lva_bridge.Bridge against a fake LVA peripheral server and a fake board.

The server sends a snapshot and a full conversation's events; the fake button is
pressed in different states. Checks the LED states and the commands the bridge
sends back. Silent; no LVA, Home Assistant or button needed.
"""
import asyncio
import json
import sys

sys.path.insert(0, '/opt/aiy/python/src/examples/voice')
import lva_bridge  # noqa: E402
from aiy.board import Led  # noqa: E402
from websockets.asyncio.server import serve  # noqa: E402

PORT = 16055


class FakeButton:
    when_pressed = None
    when_released = None


class FakeLed:
    def __init__(self):
        self.states = []

    def _set(self, state):
        self.states.append(state)

    state = property(None, _set)


class FakeBoard:
    def __init__(self):
        self.button = FakeButton()
        self.led = FakeLed()


def name(state):
    return next(n for n in dir(Led) if not n.startswith('_') and getattr(Led, n) is state)


async def scenario(board, bridge, ws, received):
    async def event(name, data=None):
        await ws.send(json.dumps({'event': name, 'data': data} if data else {'event': name}))
        await asyncio.sleep(0.05)

    def press(held):
        bridge._button(held)

    await event('snapshot', {'muted': False, 'ha_connected': True})
    press(0.2)                                   # idle -> start_listening
    await event('wake_word_detected')
    await event('listening')
    await event('stt_text', {'text': 'vad är klockan'})
    await event('thinking')
    press(0.2)                                   # busy -> stop_pipeline
    await event('tts_text', {'text': 'Klockan är tio.'})
    await event('tts_speaking')
    await event('tts_finished')
    await event('idle')
    await event('timer_ringing', {'id': '1', 'name': '', 'total_seconds': 60, 'seconds_left': 0})
    press(0.3)                                   # ringing -> stop_timer_ringing
    await event('idle')
    press(2.5)                                   # long -> mute_mic
    await event('muted', {'muted': True})
    press(2.5)                                   # long while muted -> unmute_mic
    await event('muted', {'muted': False})
    await asyncio.sleep(0.2)


async def main():
    board = FakeBoard()
    received = []
    done = asyncio.Event()
    bridge = None

    async def handler(ws):
        consumer = asyncio.create_task(collect(ws))
        await scenario(board, bridge, ws, received)
        consumer.cancel()
        done.set()

    async def collect(ws):
        async for raw in ws:
            received.append(json.loads(raw)['command'])

    async with serve(handler, 'localhost', PORT):
        bridge = lva_bridge.Bridge(board, long_press=2.0)
        task = asyncio.create_task(bridge.run(f'ws://localhost:{PORT}'))
        await asyncio.wait_for(done.wait(), 10)
        task.cancel()

    leds = [name(s) for s in board.led.states]
    want_leds = ['BLINK_3', 'OFF', 'ON', 'ON', 'BLINK', 'PULSE_QUICK', 'OFF', 'OFF',
                 'BLINK', 'OFF', 'BEACON_DARK', 'OFF']
    want_cmds = ['start_listening', 'stop_pipeline', 'stop_timer_ringing', 'mute_mic', 'unmute_mic']
    ok = True
    for label, got, want in (('LED states', leds, want_leds), ('commands', received, want_cmds)):
        good = got == want
        ok &= good
        print(f'{label:12s} {"OK" if good else "FAIL"}   {" > ".join(got)}')
        if not good:
            print(f'{"":12s} want {" > ".join(want)}')
    print('ALL OK' if ok else 'FAILED')
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(asyncio.run(main()))
