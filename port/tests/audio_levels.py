#!/usr/bin/env python3
"""Print peak/RMS level (dBFS) per channel of WAV files: audio_levels.py a.wav [b.wav ...]"""
import array
import math
import sys
import wave


def levels(path):
    with wave.open(path) as w:
        ch, sw, n = w.getnchannels(), w.getsampwidth(), w.getnframes()
        data = array.array({2: 'h', 4: 'i'}[sw], w.readframes(n))
        full = 2 ** (8 * sw - 1)
        rate = w.getframerate()
    out = []
    for c in range(ch):
        s = data[c::ch]
        peak = max((abs(x) for x in s), default=0)
        rms = math.sqrt(sum(x * x for x in s) / len(s)) if s else 0
        db = lambda v: 20 * math.log10(v / full) if v else float('-inf')
        out.append((c, db(peak), db(rms)))
    return rate, sw * 8, out


for path in sys.argv[1:]:
    rate, bits, chans = levels(path)
    for c, peak, rms in chans:
        print(f'{path} {rate}Hz {bits}bit ch{c}: peak {peak:6.1f} dBFS  rms {rms:6.1f} dBFS')
