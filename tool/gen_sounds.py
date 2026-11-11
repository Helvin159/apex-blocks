#!/usr/bin/env python3
"""Generates the Apex Blocks sound effects into assets/sfx/.

Python 3 standard library only. Output is deterministic (fixed seed).

    python3 tool/gen_sounds.py

All sounds are 44.1 kHz, 16-bit, mono, peak-normalized below -3 dBFS, with
5 ms fades at both ends so they never click.
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
PEAK_DBFS = -4.5
FADE_MS = 5
TWO_PI = 2 * math.pi

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")


def n_samples(ms):
    return int(SAMPLE_RATE * ms / 1000)


def one_pole_lowpass(samples, cutoff_hz):
    a = 1 - math.exp(-TWO_PI * cutoff_hz / SAMPLE_RATE)
    out = []
    y = 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def finish(samples):
    """Applies the end fades, then normalizes to PEAK_DBFS."""
    out = list(samples)
    fade = n_samples(FADE_MS)
    for i in range(min(fade, len(out))):
        k = i / fade
        out[i] *= k
        out[-1 - i] *= k
    peak = max(abs(s) for s in out) or 1.0
    gain = (10 ** (PEAK_DBFS / 20)) / peak
    return [s * gain for s in out]


def write_wav(name, samples):
    samples = finish(samples)
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
                for s in samples
            )
        )
    peak = max(abs(s) for s in samples)
    print(
        "%-16s %4d ms  peak %5.1f dBFS"
        % (name, len(samples) * 1000 // SAMPLE_RATE, 20 * math.log10(peak))
    )


def place(rng):
    """Short soft click: a low thump plus a lowpassed noise tick."""
    n = n_samples(40)
    noise = one_pole_lowpass([rng.uniform(-1, 1) for _ in range(n)], 3500)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        thump = math.sin(TWO_PI * 170 * t) * math.exp(-t * 90)
        tick = noise[i] * math.exp(-t * 220)
        out.append(0.8 * thump + 0.6 * tick)
    return out


def clear(step, rng):
    """Engine rev: a rising harmonic sweep. Each step starts higher."""
    n = n_samples(250)
    base = 95 * 1.12 ** step
    top = base * 2.4
    harmonics = [(1, 1.0), (2, 0.5), (3, 0.33), (4, 0.25)]
    noise = one_pole_lowpass([rng.uniform(-1, 1) for _ in range(n)], 2500)
    out = []
    phase = 0.0
    for i in range(n):
        p = i / n
        t = i / SAMPLE_RATE
        freq = base * (top / base) ** (p ** 0.8)
        phase += TWO_PI * freq / SAMPLE_RATE
        tone = sum(a * math.sin(h * phase) for h, a in harmonics)
        flutter = 0.75 + 0.25 * math.sin(TWO_PI * 40 * t)
        env = min(1.0, t / 0.012) * (1.0 - 0.55 * p)
        grit = math.tanh(1.8 * tone * flutter) + 0.15 * noise[i]
        out.append(grit * env)
    return out


def light():
    """Start-light beep."""
    n = n_samples(120)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.006) * math.exp(-t * 14)
        out.append(
            (math.sin(TWO_PI * 880 * t) + 0.3 * math.sin(TWO_PI * 1760 * t)) * env
        )
    return out


def lights_out(rng):
    """Whoosh: noise through a swept band-pass, swelling then fading."""
    n = n_samples(400)
    out = []
    low = band = 0.0
    q = 0.35
    for i in range(n):
        p = i / n
        t = i / SAMPLE_RATE
        # Center frequency sweeps 400 Hz -> 3200 Hz.
        fc = 400 * (3200 / 400) ** p
        f = 2 * math.sin(math.pi * fc / SAMPLE_RATE)
        x = rng.uniform(-1, 1)
        low += f * band
        high = x - low - q * band
        band += f * high
        env = math.sin(math.pi * p ** 0.6) ** 1.5
        # A short low drop under the front of the whoosh.
        drop = math.sin(TWO_PI * 90 * t) * math.exp(-t * 18) * 0.4
        out.append(band * env + drop)
    return out


def main():
    rng = random.Random(1159)
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav("place.wav", place(rng))
    for step in range(6):
        write_wav("clear_%d.wav" % (step + 1), clear(step, rng))
    write_wav("light.wav", light())
    write_wav("lights_out.wav", lights_out(rng))


if __name__ == "__main__":
    main()
