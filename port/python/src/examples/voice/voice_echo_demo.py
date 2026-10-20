# Licensed under the Apache License, Version 2.0.
"""Push-to-talk echo: hold the button and speak, release it to hear yourself back.

Needs no network or account. The LED is on while recording and pulses while playing.
Presses shorter than --min_seconds are ignored, and a recording stops by itself after
--max_seconds. Runs at boot as voice_echo_demo.service (installed disabled).
"""
import argparse
import logging
import os
import tempfile
import threading
import wave

from aiy.board import Board, Led
from aiy.voice import tts
from aiy.voice.audio import AudioFormat, FilePlayer, record_file

FORMAT = AudioFormat(sample_rate_hz=16000, num_channels=1, bytes_per_sample=2)


def recorded_seconds(filename):
    with wave.open(filename) as w:
        return w.getnframes() / w.getframerate()


def echo_once(button, led, filename, min_seconds, max_seconds, device):
    """Waits for one press, records until release, and plays it back.

    Returns the recorded length in seconds (0 when it was too short to play).
    """
    button.wait_for_press()
    released = threading.Event()
    # Set right away: the button ignores releases for 80 ms after a press, so a
    # quick tap can't slip past while arecord starts.
    button.when_released = released.set
    led.state = Led.ON
    record_file(FORMAT, filename=filename, filetype='wav',
                wait=lambda: released.wait(max_seconds), device='default')
    button.when_released = None
    seconds = recorded_seconds(filename)
    if seconds < min_seconds:
        led.state = Led.OFF
        logging.info('Ignored a %.2f s press', seconds)
        return 0
    logging.info('Playing back %.2f s', seconds)
    led.state = Led.PULSE_QUICK
    with FilePlayer() as player:
        player.play_wav(filename, device=device)
    led.state = Led.OFF
    return seconds


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--min_seconds', type=float, default=0.5)
    parser.add_argument('--max_seconds', type=float, default=15)
    parser.add_argument('--greeting', default='',
                        help='text to say once at start (pico2wave), e.g. "Ready"')
    parser.add_argument('--device', default='default', help='ALSA playback device')
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(message)s')

    with Board() as board, tempfile.TemporaryDirectory() as tmp:
        filename = os.path.join(tmp, 'echo.wav')
        if args.greeting:
            tts.say(args.greeting, device=args.device)
        logging.info('Hold the button and speak; release to hear it back (Ctrl-C to exit).')
        while True:
            echo_once(board.button, board.led, filename,
                      args.min_seconds, args.max_seconds, args.device)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
