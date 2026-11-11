#!/usr/bin/env python3
"""Generates the Apex Blocks sound effects into assets/sfx/.

clear_1..6: bell chime climbing a pentatonic scale per combo step.
passby_full / passby_short: stylized V6 turbo single-seater flying past
(lights out; FASTEST LAP and NEW POLE). All sounds are original, synthesized
here; nothing is sampled or downloaded.

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


# Rising major-pentatonic notes, one per combo step (combo 1..6+).
CHIME_NOTES_HZ = [659.3, 784.0, 880.0, 1046.5, 1174.7, 1318.5]


def mix(a, b, offset=0, gain_b=1.0):
    """Adds b into a starting at sample `offset`, extending as needed."""
    out = [0.0] * max(len(a), offset + len(b))
    for i, s in enumerate(a):
        out[i] += s
    for i, s in enumerate(b):
        out[offset + i] += s * gain_b
    return out


def bell(freq, ms=600, brightness=1.0):
    """Bell-like tone: a few slightly inharmonic partials, each decaying."""
    partials = [
        (1.0, 1.0, 5.0),
        (2.0, 0.45 * brightness, 8.0),
        (3.01, 0.22 * brightness, 12.0),
        (4.2, 0.10 * brightness, 18.0),
    ]
    out = []
    for i in range(n_samples(ms)):
        t = i / SAMPLE_RATE
        attack = min(1.0, t / 0.003)
        out.append(
            attack
            * sum(
                amp * math.sin(TWO_PI * freq * ratio * t) * math.exp(-t * decay)
                for ratio, amp, decay in partials
            )
        )
    return out


def clear(step, rng):
    """Line-clear chime: root note, a fifth 55 ms later, and from combo 3 an
    octave sparkle at 110 ms. Each combo step uses the next note up."""
    freq = CHIME_NOTES_HZ[min(step, len(CHIME_NOTES_HZ) - 1)]
    out = bell(freq)
    out = mix(out, bell(freq * 1.5, 520, 0.8), n_samples(55), 0.55)
    if step >= 2:
        out = mix(out, bell(freq * 2, 460, 0.6), n_samples(110), 0.4)
    return out


def _formant(freq):
    """Exhaust and body resonances that shape the engine's harmonics."""
    return (
        1.0 / (1 + ((freq - 1100) / 500) ** 2)
        + 0.7 / (1 + ((freq - 2400) / 700) ** 2)
        + 0.35 / (1 + ((freq - 450) / 250) ** 2)
    )


def passby(dur_s, speed_ms, dist_m, pass_at_s, rpm_fn, rng, whistle=0.06):
    """Stylized single-seater V6 turbo flying past at top speed.

    A V6 four-stroke fires 3 times per revolution, so the engine note is
    rpm / 60 * 3 (about 575 Hz at 11,500 rpm, well inside what phone speakers
    play). The car moves along a straight line `dist_m` from the listener and
    passes at `pass_at_s`; Doppler shift, 1/r loudness and distance dulling
    are applied per sample. Includes a turbo whistle and exhaust noise.
    """
    speed_of_sound = 343.0
    n = n_samples(dur_s * 1000)
    max_harmonic = 14
    phases = [0.0] * (max_harmonic + 1)
    rev_phase = turbo_phase = 0.0
    lowpassed = noise = 0.0
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        x = speed_ms * (t - pass_at_s)
        r = math.sqrt(x * x + dist_m * dist_m)
        radial_v = speed_ms * x / r  # negative approaching, positive leaving
        doppler = speed_of_sound / (speed_of_sound + radial_v)
        rpm = rpm_fn(t)
        fire_hz = rpm / 60 * 3 * doppler
        rev_phase += TWO_PI * (fire_hz / 3) / SAMPLE_RATE
        rough = 1 + 0.22 * math.sin(rev_phase) + 0.08 * math.sin(2 * rev_phase + 1.3)
        s = 0.0
        for h in range(1, max_harmonic + 1):
            f = fire_hz * h
            if f > 9000:
                break
            phases[h] += TWO_PI * f / SAMPLE_RATE
            s += math.sin(phases[h]) * _formant(f) / h ** 0.55
        s *= rough
        turbo_phase += TWO_PI * (rpm / 60 * 9.7 * doppler) / SAMPLE_RATE
        s += whistle * 5 * math.sin(turbo_phase)
        noise += 0.25 * (rng.uniform(-1, 1) - noise)
        s += 0.35 * noise * rough
        s = math.tanh(0.9 * s)
        loudness = 1 / max(r, dist_m) ** 1.15
        cutoff = 900 + 7000 * (dist_m / r) ** 1.5  # far away sounds duller
        a = 1 - math.exp(-TWO_PI * cutoff / SAMPLE_RATE)
        lowpassed += a * (s - lowpassed)
        out.append(lowpassed * loudness)
    return out


def _rpm_full(t):
    """Near the limiter, with one quick upshift just before passing."""
    rpm = 11200 + 500 * min(1.0, t / 0.6)
    if 0.55 < t < 0.62:
        rpm -= 1600 * (1 - (t - 0.55) / 0.07)
    return rpm


def passby_full(rng):
    """Lights out: approach, upshift, scream past, fade away (1.8 s)."""
    return passby(1.8, 86.0, 9.0, 0.9, _rpm_full, rng)


def passby_short(rng):
    """FASTEST LAP / NEW POLE: a quicker, closer pass (0.9 s)."""
    return passby(0.9, 92.0, 7.0, 0.42, lambda t: 11900, rng)


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


def main():
    rng = random.Random(1159)
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav("place.wav", place(rng))
    for step in range(6):
        write_wav("clear_%d.wav" % (step + 1), clear(step, rng))
    write_wav("light.wav", light())
    write_wav("passby_full.wav", passby_full(rng))
    write_wav("passby_short.wav", passby_short(rng))


if __name__ == "__main__":
    main()
