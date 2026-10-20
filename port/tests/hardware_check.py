#!/usr/bin/env python3
"""Checks the Voice HAT through the aiy library: button LED, mic, playback path and TTS.

Silent by default: playback and TTS go to the ALSA "null" device. With --play they
go to the speaker at a low volume; with --button, it also waits for a press of the
arcade button.
"""
import argparse
import array
import math
import os
import subprocess
import tempfile
import time
import wave

from aiy.board import Board, Led
from aiy.voice import audio, tts


def check(name, ok, detail=''):
    print('%-34s %s %s' % (name, 'OK  ' if ok else 'FAIL', detail), flush=True)
    return ok


def rms_dbfs(path):
    with wave.open(path) as w:
        samples = array.array('h', w.readframes(w.getnframes()))
    rms = math.sqrt(sum(x * x for x in samples) / len(samples)) if samples else 0
    return 20 * math.log10(rms / 32768) if rms else float('-inf')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--play', action='store_true',
                        help='play the recording and the TTS on the speaker (Master at 20%%)')
    parser.add_argument('--button', type=int, default=0, metavar='SECONDS',
                        help='wait this long for an arcade button press')
    args = parser.parse_args()
    device = 'default' if args.play else 'null'
    results = []

    with Board() as board:
        results.append(check('LED class', Led.__name__ == 'SingleColorLed', Led.__name__))
        for state in (Led.ON, Led.BLINK, Led.PULSE_QUICK, Led.OFF):
            board.led.state = state
            time.sleep(1)
        results.append(check('LED states (on/blink/pulse/off)', True))

        with tempfile.TemporaryDirectory() as tmp:
            wav = os.path.join(tmp, 'rec.wav')
            fmt = audio.AudioFormat(sample_rate_hz=16000, num_channels=1, bytes_per_sample=2)
            audio.record_file(fmt, filename=wav, filetype='wav', wait=lambda: time.sleep(2))
            with wave.open(wav) as w:
                seconds = w.getnframes() / w.getframerate()
            level = rms_dbfs(wav)
            # arecord takes ~0.25 s to start and loses its buffer when terminated, so
            # 2 s of waiting gives ~1.75 s. The room's floor with the x4 gain is about
            # -64 dBFS; digital silence (a dead mic or wrong device) is -inf.
            results.append(check('record 2 s (default, 16 kHz)', seconds >= 1.5 and level > -90,
                                 '%.2f s, rms %.1f dBFS' % (seconds, level)))

            if args.play:
                subprocess.run(['amixer', '-q', 'sset', 'Master', '20%'], check=True)
            player = audio.play_wav_async(wav) if args.play else \
                subprocess.Popen(['aplay', '-q', '-D', device, wav])
            results.append(check('play the recording (%s)' % device, player.wait() == 0))

        tts.say('Voice kit check', device=device)
        results.append(check('tts.say (%s)' % device, True))
        tts.say('Quotes "here", $HOME and `backticks`', device='null')
        results.append(check('tts.say with shell characters', True))

        if args.button:
            print('Press the arcade button within %d s...' % args.button, flush=True)
            board.led.state = Led.ON
            pressed = board.button.wait_for_press(timeout=args.button)
            board.led.state = Led.OFF
            results.append(check('button press', pressed))

    print('ALL OK' if all(results) else 'SOME CHECKS FAILED')
    return 0 if all(results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
