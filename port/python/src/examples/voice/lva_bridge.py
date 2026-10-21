# Licensed under the Apache License, Version 2.0.
"""Voice HAT button and LED for Linux Voice Assistant (Home Assistant satellite).

Connects to LVA's peripheral WebSocket API and:
- shows the voice pipeline on the LED: listening ON, thinking BLINK, speaking
  PULSE_QUICK, idle OFF, muted a faint BEACON_DARK, no connection BLINK_3,
  timer ringing BLINK;
- uses the arcade button: a short press starts a conversation, or stops the
  current one or a ringing timer; a long press (2 s) mutes the mic, and any
  press while muted unmutes it (LVA ignores start_listening while muted).

LVA plays the sounds and talks to Home Assistant; this only drives the GPIOs.
"""

import argparse
import asyncio
import json
import logging
import time

from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosed

from aiy.board import Board, Led

logger = logging.getLogger('lva_bridge')

LED_FOR_EVENT = {
    'wake_word_detected': Led.ON,
    'listening': Led.ON,
    'thinking': Led.BLINK,
    'tts_speaking': Led.PULSE_QUICK,
    'tts_finished': Led.OFF,
    'idle': Led.OFF,
    'pipeline_error': Led.BLINK_3,
    'timer_ringing': Led.BLINK,
    'disconnected': Led.BLINK_3,
}
BUSY = {'wake_word_detected', 'listening', 'thinking', 'tts_speaking'}


class Bridge:
    def __init__(self, board, long_press):
        self._board = board
        self._long_press = long_press
        self._state = 'idle'
        self._muted = False
        self._pressed_at = 0.0
        self._commands = asyncio.Queue()
        self._loop = asyncio.get_running_loop()
        board.button.when_pressed = self._on_press
        board.button.when_released = self._on_release

    def _set_led(self, state):
        self._board.led.state = state

    # Button callbacks run on aiy.board's button thread.
    def _on_press(self):
        self._pressed_at = time.monotonic()

    def _on_release(self):
        held = time.monotonic() - self._pressed_at
        self._loop.call_soon_threadsafe(self._button, held)

    def _button(self, held):
        if self._muted:
            command = 'unmute_mic'
        elif held >= self._long_press:
            command = 'mute_mic'
        elif self._state == 'timer_ringing':
            command = 'stop_timer_ringing'
        elif self._state in BUSY:
            command = 'stop_pipeline'
        else:
            command = 'start_listening'
        logger.info('button %.1f s -> %s', held, command)
        self._commands.put_nowait(command)

    def _handle(self, message):
        event = message.get('event')
        data = message.get('data') or {}
        if event == 'snapshot':
            self._muted = data.get('muted', False)
            event = 'idle' if data.get('ha_connected') else 'disconnected'
        elif event == 'muted':
            self._muted = data.get('muted', False)
            event = 'idle'
        elif event in ('stt_text', 'tts_text'):
            logger.info('%s: %s', event, data.get('text'))
            return
        if event not in LED_FOR_EVENT:
            return
        self._state = event
        if event == 'idle' and self._muted:
            self._set_led(Led.BEACON_DARK)
        else:
            self._set_led(LED_FOR_EVENT[event])

    async def _send_commands(self, ws):
        while True:
            command = await self._commands.get()
            await ws.send(json.dumps({'command': command}))

    async def run(self, uri):
        self._set_led(Led.BLINK_3)
        # connect() as an async iterator reconnects with backoff.
        async for ws in connect(uri, open_timeout=5):
            logger.info('connected to %s', uri)
            sender = asyncio.create_task(self._send_commands(ws))
            try:
                async for raw in ws:
                    self._handle(json.loads(raw))
            except ConnectionClosed:
                pass
            finally:
                sender.cancel()
            logger.info('connection lost, retrying')
            self._state = 'disconnected'
            self._set_led(Led.BLINK_3)


async def main_async(args):
    with Board() as board:
        await Bridge(board, args.long_press).run(args.uri)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--uri', default='ws://localhost:6055',
                        help='LVA peripheral API (default: ws://localhost:6055)')
    parser.add_argument('--long_press', type=float, default=2.0,
                        help='seconds held to mute/unmute the mic (default: 2)')
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(name)s: %(message)s')
    try:
        asyncio.run(main_async(args))
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
