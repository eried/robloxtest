# Sounds and music for Pianka the Escape: python3 escape/tools/make_audio.py
# Writes escape/sounds/PiankaEscapeSfx.mp3, the music in escape/music and prints the clip table for Config.luau
# Voice lines in escape/sounds/voice were made once with Piper (en-us lessac and amy voices)
import json
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(7)
ROOT = os.path.join(os.path.dirname(__file__), "..")


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def lowpass(x, k):
    return np.convolve(x, np.ones(k) / k, mode="same")


def band(x, lo, hi):
    f = np.fft.rfftfreq(len(x), 1 / SR)
    s = np.fft.rfft(x)
    s[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(s, len(x))


def env(n, a, r):
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return e


def norm(x, peak=0.9):
    return x / max(np.abs(x).max(), 1e-9) * peak


def reverb(x, wet=0.25, decay=3.0, length=1.2, seed=3):
    g = np.random.default_rng(seed)
    n = int(length * SR)
    t = np.arange(n) / SR
    ir = g.standard_normal(n) * np.exp(-t * decay)
    ir = lowpass(ir, 6)
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    w = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x) + n]
    out = np.zeros(len(w))
    out[: len(x)] += x
    return out * (1 - wet) + w * wet * np.abs(x).max() / max(np.abs(w).max(), 1e-9)


def mix(parts, total):
    out = np.zeros(int(total * SR) + SR)
    for t0, sig, gain in parts:
        i = int(t0 * SR)
        if i >= len(out):
            continue
        out[i : i + len(sig)] += sig[: len(out) - i] * gain
    return out


def loop(parts, total):
    """Mixes a loop and folds the tail back to the start so it repeats without a seam."""
    out = mix(parts, total + 3)
    body = out[: int(total * SR)].copy()
    tail = out[int(total * SR) :]
    body[: len(tail)] += tail[: len(body)]
    return body


def load_wav(path, semis=0.0, tempo=1.0):
    filt = f"aresample={SR}"
    if semis or tempo != 1.0:
        filt += f",rubberband=pitch={2 ** (semis / 12):.5f}:tempo={tempo:.4f}:formant=preserved"
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-af", filt, "-ac", "1", "-f", "s16le", "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.int16).astype(float) / 32768
    e = np.abs(x)
    idx = np.where(e > 0.02 * e.max())[0]
    return x[max(idx[0] - 200, 0) : idx[-1] + 600]


# Instruments ---------------------------------------------------------------


def bell(freq, dur=2.5, gain=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for ratio, amp, dec in ((1, 1, 1.4), (2.76, 0.4, 2.4), (5.4, 0.2, 3.6), (8.9, 0.08, 5)):
        sig += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * dec)
    return sig * env(n, 0.002, 0.2) * 0.12 * gain


def music_box(freq, dur=1.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * freq * t) * np.exp(-t * 3.2) + 0.35 * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-t * 7) + 0.15 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t * 12)
    return sig * env(n, 0.001, 0.1) * 0.25


def pluck(freq, dur=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for h in range(1, 12):
        sig += (1 / h) * np.exp(-t * (6.0 + h * 2.2)) * np.sin(2 * np.pi * h * freq * t)
    return sig * env(n, 0.003, 0.04) * 0.5


def upright(freq, dur=0.7, seed=0):
    """Plucked upright bass, Karplus-Strong, with an octave on top so phones can hear it."""
    g = np.random.default_rng(seed)
    n = int(dur * SR)
    out = np.zeros(n)
    for f, amp in ((freq, 1.0), (freq * 2, 0.35)):
        p = max(2, int(SR / f))
        y = np.zeros(n + p + 1)
        y[: p + 1] = lowpass(g.uniform(-1, 1, p + 1), 4)
        k = p + 1
        while k < n + p + 1:
            m = min(p, n + p + 1 - k)
            y[k : k + m] = 0.994 * 0.5 * (y[k - p : k - p + m] + y[k - p - 1 : k - p - 1 + m])
            k += m
        out += amp * y[p + 1 : p + 1 + n]
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * freq * t) * np.exp(-t * 18) * 0.6
    return (out * 0.5 + thump) * env(n, 0.004, 0.08)


def vibes(freq, dur=1.2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    trem = 1 + 0.25 * np.sin(2 * np.pi * 5.5 * t)
    sig = np.sin(2 * np.pi * freq * t) * np.exp(-t * 2.2) + 0.25 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t * 8) + 0.1 * np.sin(2 * np.pi * freq * 10 * t) * np.exp(-t * 20)
    return sig * trem * env(n, 0.002, 0.15) * 0.3


def snap(seed=0):
    g = np.random.default_rng(seed)
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    return band(g.standard_normal(n), 1400, 3600) * np.exp(-t * 70) * 0.9


def brush(dur=0.35, seed=0):
    g = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    shape = np.minimum(t / 0.06, 1) * np.exp(-t * 7)
    return band(g.standard_normal(n), 2500, 9000) * shape * 0.25


def hat(seed=0):
    g = np.random.default_rng(seed)
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    return band(g.standard_normal(n), 6000, 14000) * np.exp(-t * 90) * 0.18


def strings(freqs, dur, trem=8.5, bright=1600, seed=0):
    g = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for f in freqs:
        for cents in (-7, 0, 6):
            ff = f * 2 ** (cents / 1200)
            ph = g.uniform(0, 1)
            sig += 2 * ((ff * t + ph) % 1) - 1
    sig = band(sig, 40, bright)
    am = 0.65 + 0.35 * np.sin(2 * np.pi * trem * t)
    return sig * am * env(n, 0.4, 0.4) / (3 * len(freqs))


def heartbeat():
    n = int(0.5 * SR)
    t = np.arange(n) / SR

    def thump(k):
        f = 55 + 40 * np.exp(-k * 30)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-k * 16) + 0.15 * band(np.random.default_rng(1).standard_normal(len(k)), 200, 900) * np.exp(-k * 60)

    out = thump(t) * 1.0
    second = thump(t[: n - int(0.2 * SR)]) * 0.7
    out[int(0.2 * SR) :] += second
    return out


def tick(f=3200, seed=0):
    n = int(0.03 * SR)
    t = np.arange(n) / SR
    g = np.random.default_rng(seed)
    return (np.sin(2 * np.pi * f * t) + 0.4 * g.standard_normal(n)) * np.exp(-t * 220) * 0.3


# Music ---------------------------------------------------------------------

BEAT = 0.6
BARS = 16
CHORDS = ["Dm", "Dm", "Gm", "A7", "Dm", "Bb", "Gm", "A7"]
CHORD_ROOT = {"Dm": 38, "Gm": 43, "A7": 45, "Bb": 46}
TONES = {"Dm": [0, 3, 7, 10], "Gm": [0, 3, 7, 9], "A7": [0, 4, 7, 10], "Bb": [0, 4, 7, 9]}


def chord_at(bar):
    return CHORDS[(bar // 2) % len(CHORDS)]


def stealth_calm():
    """A sneaky detective tune: walking bass, finger snaps, brushes and tip-toe vibes."""
    total = BARS * 4 * BEAT
    parts = []
    swing = BEAT * 2 / 3
    for bar in range(BARS):
        t0 = bar * 4 * BEAT
        c = chord_at(bar)
        nxt = CHORD_ROOT[chord_at(bar + 1)]
        r = CHORD_ROOT[c]
        tones = TONES[c]
        walk = [r, r + tones[1], r + tones[2], nxt + (1 if bar % 2 == 0 else -1)]
        if bar % 2 == 1:
            walk = [r + 12, r + tones[2], r + tones[1], nxt - 1]
        for b, m in enumerate(walk):
            parts.append((t0 + b * BEAT, upright(midi(m), 0.75, seed=bar * 4 + b), 0.9))
            # The same line an octave up, softly, so phone speakers carry the walking bass
            parts.append((t0 + b * BEAT, pluck(midi(m + 12), 0.4), 0.3))
        for b in (1, 3):
            parts.append((t0 + b * BEAT, snap(seed=bar * 2 + b), 0.55))
        for b in (0, 2):
            parts.append((t0 + b * BEAT, brush(seed=bar + b), 0.8))
        for b in range(4):
            parts.append((t0 + b * BEAT, hat(seed=bar * 8 + b), 0.6))
            parts.append((t0 + b * BEAT + swing, hat(seed=bar * 8 + b + 4), 0.35))
    # Tip-toe melody: call and answer over the chords
    m1 = [(0.66, 74, 0.25), (1.0, 76, 0.25), (1.66, 77, 0.25), (2.66, 78, 0.25), (3.0, 79, 0.5), (4.0, 81, 0.9), (5.66, 82, 0.25), (6.0, 81, 1.4)]
    m2 = [(0.66, 81, 0.25), (1.0, 79, 0.25), (1.66, 77, 0.25), (2.0, 76, 0.4), (3.0, 73, 0.5), (4.0, 74, 1.8)]
    m3 = [(0.66, 77, 0.25), (1.0, 74, 0.25), (1.66, 70, 0.25), (2.66, 72, 0.25), (3.0, 74, 0.5), (4.0, 77, 0.9), (5.66, 76, 0.25), (6.0, 74, 1.4)]
    m4 = [(0.66, 81, 0.25), (1.0, 79, 0.25), (1.66, 76, 0.25), (2.0, 73, 0.4), (3.0, 76, 0.5), (4.0, 69, 1.8)]
    for start, motif in ((2, m1), (6, m2), (10, m3), (14, m4)):
        for beat, m, d in motif:
            parts.append((start * 4 * BEAT + beat * BEAT, vibes(midi(m), max(0.5, d * 1.6)), 1.0))
    return norm(reverb(loop(parts, total), 0.18, 3, 1.0)[: int(total * SR)], 0.85)


def stealth_tense():
    """Same length and chords: tremolo strings, a heartbeat, a ticking clock and a cold high cluster."""
    total = BARS * 4 * BEAT
    parts = []
    for i, c in enumerate(CHORDS):
        t0 = i * 8 * BEAT
        r = CHORD_ROOT[c]
        parts.append((t0, strings([midi(r), midi(r + 12), midi(r + 12 + TONES[c][2])], 8 * BEAT + 0.3, seed=i), 1.0))
        parts.append((t0, strings([midi(r + 24 + 1)], 8 * BEAT + 0.3, trem=11, bright=3000, seed=i + 20), 0.6))
        # A nervous ostinato in the middle, where phone speakers can play it
        for e in range(16):
            note = r + 24 + (0, 1, 0, 3)[e % 4]
            parts.append((t0 + e * BEAT / 2, pluck(midi(note), 0.22), 0.55))
    for bar in range(BARS):
        t0 = bar * 4 * BEAT
        for b in (0, 2):
            parts.append((t0 + b * BEAT, heartbeat(), 0.8))
        for e in range(8):
            parts.append((t0 + e * BEAT / 2, tick(2600 if e % 2 else 3400, seed=bar * 8 + e), 0.5))
    n = int(total * SR)
    t = np.arange(n) / SR
    swell = 0.5 - 0.5 * np.cos(2 * np.pi * t / (8 * BEAT * 2))
    cluster = (np.sin(2 * np.pi * midi(86) * t + 0.3 * np.sin(2 * np.pi * 5 * t)) + np.sin(2 * np.pi * midi(87) * t + 0.3 * np.sin(2 * np.pi * 4.3 * t))) * swell * 0.05
    drone = np.sin(2 * np.pi * midi(26) * t) * 0.12 + band(rng.standard_normal(n), 30, 160) * 0.08
    parts.append((0, cluster + drone, 1.0))
    return norm(reverb(loop(parts, total), 0.3, 2.2, 1.6)[: int(total * SR)], 0.85)


def bubble_blip(freq, seed=0):
    """A little bubble: a sine that slides up and pops."""
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    f = freq * (1 + 1.6 * (t / 0.12) ** 1.5)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 28) * env(n, 0.003, 0.02) * 0.35


def dream_box():
    """A bubbly love waltz for the dream: oom-pah-pah, music box tune, bubbles and sparkles."""
    beat = 0.4
    tune = [
        (0, 72, 1), (1, 69, 1), (2, 72, 1), (3, 77, 2), (5, 76, 1), (6, 74, 1), (7, 77, 1), (8, 74, 1), (9, 72, 3),
        (12, 69, 1), (13, 74, 1), (14, 77, 1), (15, 77, 1), (16, 76, 1), (17, 74, 1), (18, 70, 1), (19, 74, 1), (20, 79, 1), (21, 76, 2), (23, 79, 1),
        (24, 81, 1), (25, 79, 1), (26, 77, 1), (27, 84, 2), (29, 81, 1), (30, 82, 1), (31, 79, 1), (32, 76, 1), (33, 77, 3),
    ]
    chords = [(53, [65, 69, 72]), (53, [65, 69, 72]), (46, [65, 70, 74]), (48, [64, 67, 72]), (50, [65, 69, 74]), (46, [65, 70, 74]),
              (43, [67, 70, 74]), (48, [64, 67, 70]), (53, [65, 69, 72]), (53, [65, 69, 72]), (46, [65, 70, 74]), (53, [65, 69, 72])]
    parts = []
    for b, m, d in tune:
        parts.append((b * beat, music_box(midi(m), 1.4 + d * 0.4), 1.0))
        parts.append((b * beat, music_box(midi(m + 12), 0.8), 0.25))
    for bar, (bass, triad) in enumerate(chords):
        t0 = bar * 3 * beat
        parts.append((t0, pluck(midi(bass), 0.5), 0.9))
        for b in (1, 2):
            for m in triad:
                parts.append((t0 + b * beat, vibes(midi(m), 0.35), 0.3))
        # Bubbles on the off beats, rising
        for i, off in enumerate((0.5, 1.5, 2.5)):
            if (bar + i) % 2 == 0:
                parts.append((t0 + off * beat, bubble_blip(midi(triad[i % 3] + 12)), 0.8))
    # Sparkles at the start, the hug and the end
    for t0 in (0.0, 9.6, 13.2):
        for i, m in enumerate((89, 93, 96, 101)):
            parts.append((t0 + i * 0.07, bell(midi(m), 1.0, 1.0), 1.0))
    total = 12 * 3 * beat + 1.6
    n = int(total * SR)
    t = np.arange(n) / SR
    pad = sum(np.sin(2 * np.pi * midi(m) * t * (1 + 0.003 * np.sin(2 * np.pi * 0.4 * t))) for m in (65, 69, 72, 77)) * 0.018 * np.minimum(t / 1.5, 1) * np.minimum((total - t) / 1.5, 1)
    parts.append((0, pad, 1.0))
    return norm(reverb(mix(parts, total)[:n], 0.35, 2.2, 1.6), 0.85)


# Sound effects -------------------------------------------------------------


def shaped(g, n, peaks, lo=80, hi=6000, tilt=0.5, noise=None):
    """Noise with a smooth spectrum: wide soft peaks, gentle slopes, a pink tilt. RMS 1."""
    x = noise if noise is not None else g.standard_normal(n)
    f = np.fft.rfftfreq(n, 1 / SR)
    spec = np.full(len(f), 0.05)
    for fc, bw, gain in peaks:
        spec += gain * np.exp(-0.5 * ((f - fc) / bw) ** 2)
    spec /= np.sqrt(1 + (lo / np.maximum(f, 1)) ** 4)
    spec /= np.sqrt(1 + (f / hi) ** 4)
    spec *= (np.maximum(f, 40) / 1000) ** -tilt
    y = np.fft.irfft(np.fft.rfft(x) * spec, n)
    return y / max(np.sqrt(np.mean(y ** 2)), 1e-9)


def curve(n, a, b):
    """A smooth swell from 0 to 1 and back: rises like x^a, falls like (1 - x)^b."""
    x = np.linspace(0, 1, n)
    e = x ** a * (1 - x) ** b
    return e / max(e.max(), 1e-9)


def drift(g, n, rate):
    """Slow random wobble around 0, about -1 to 1, changing about rate times a second."""
    f = np.fft.rfftfreq(n, 1 / SR)
    y = np.fft.irfft(np.fft.rfft(g.standard_normal(n)) * np.exp(-0.5 * (f / rate) ** 2), n)
    return y / max(np.abs(y).max(), 1e-9)


def flutter(g, n, f0, span):
    """Soft palate flutter: uneven soft pulses near f0 Hz, each a little different."""
    freq = f0 + span * drift(g, n, 2.5) + 2.5 * drift(g, n, 9)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    cycles = int(phase[-1] / (2 * np.pi)) + 2
    amp = g.uniform(0.45, 1.0, cycles)
    shape = g.uniform(1.5, 3.0, cycles)
    k = (phase / (2 * np.pi)).astype(int)
    return amp[k] * ((1 - np.cos(phase)) / 2) ** shape[k]


def snoring(light):
    """Snoring recorded by iamgiorgio (freesound.org 371299). The kids get a softer, higher one."""
    filt = f"aresample={SR},atrim=0:12.0,acompressor=threshold=0.06:ratio=3:attack=15:release=300"
    if light:
        filt += ",highpass=f=220,lowpass=f=3600,rubberband=pitch=1.18:tempo=1.1,acompressor=threshold=0.05:ratio=4:attack=10:release=250"
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(ROOT, "sounds", "snore.mp3"), "-af", filt, "-ac", "1", "-f", "s16le", "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.int16).astype(float) / 32768
    return norm(x * env(len(x), 0.15, 0.4), 0.6 if light else 0.8)


def squeak(double):
    def one(d, f0, rise):
        n = int(d * SR)
        t = np.arange(n) / SR
        f = f0 + rise * np.sin(np.pi * t / d) + 25 * np.sin(2 * np.pi * 38 * t)
        ph = 2 * np.pi * np.cumsum(f) / SR
        tone = np.tanh(2.2 * np.sin(ph)) + 0.25 * np.sin(2 * ph)
        air = lowpass(rng.standard_normal(n), 3) * 0.12
        return (tone + air) * env(n, 0.01, 0.06)

    if double:
        return norm(np.concatenate([one(0.2, 1300, 600), np.zeros(int(0.06 * SR)), one(0.32, 1450, 700)]))
    return norm(one(0.36, 1350, 650))


def ball_track():
    d = 2.2
    n = int(d * SR)
    t = np.arange(n) / SR
    speed = np.exp(-t * 1.1)
    rate = 9 + 14 * speed
    ph = np.cumsum(rate) / SR
    ticks = (np.diff(np.floor(ph), prepend=0) > 0).astype(float)
    k = np.arange(int(0.02 * SR)) / SR
    click = np.exp(-k * 400) * np.sin(2 * np.pi * 2600 * k)
    clicks = np.convolve(ticks * (0.5 + 0.5 * speed), click)[:n]
    roll = lowpass(rng.standard_normal(n), 12) * (0.4 * speed + 0.05) * (1 + 0.5 * np.sin(2 * np.pi * rate * t))
    whir = 0.15 * np.sin(2 * np.pi * (180 + 120 * speed) * t) * speed
    return norm((clicks + roll + whir) * env(n, 0.02, 0.4))


def metal_hit(freq=420, decay=14, seed=0, length=0.4):
    g = np.random.default_rng(seed)
    m = int(length * SR)
    k = np.arange(m) / SR
    sig = sum(a * np.sin(2 * np.pi * freq * r * k) for r, a in ((1, 0.6), (2.69, 0.35), (4.2, 0.2), (6.1, 0.1)))
    return (sig + g.standard_normal(m) * 0.25 * np.exp(-k * 80)) * np.exp(-k * decay)


def unlock():
    parts = []
    k = np.arange(int(0.08 * SR)) / SR
    for t0, f in ((0.0, 3200), (0.18, 2800), (0.36, 3400)):
        parts.append((t0, np.exp(-k * 160) * (np.sin(2 * np.pi * f * k) + 0.5 * rng.standard_normal(len(k))), 0.7))
    m = np.arange(int(0.35 * SR)) / SR
    clunk = np.exp(-m * 18) * np.sin(2 * np.pi * (90 + 40 * np.exp(-m * 30)) * m) + np.exp(-m * 60) * rng.standard_normal(len(m)) * 0.3
    parts.append((0.6, clunk, 1.0))
    return norm(mix(parts, 1.0)[: int(1.0 * SR)])


def lock_clunk():
    """A heavy padlock snapping shut."""
    parts = [(0, metal_hit(380, 12, 1, 0.5), 1.0), (0.0, metal_hit(1150, 30, 2, 0.2), 0.5)]
    m = np.arange(int(0.3 * SR)) / SR
    parts.append((0, np.sin(2 * np.pi * (70 + 50 * np.exp(-m * 40)) * m) * np.exp(-m * 14), 0.9))
    return norm(reverb(mix(parts, 0.7)[: int(0.7 * SR)], 0.25, 4, 0.8))


def rattle():
    """Trying the locked door handle."""
    parts = []
    for i, t0 in enumerate((0.0, 0.14, 0.26, 0.42, 0.55, 0.7)):
        parts.append((t0, metal_hit(900 + 140 * (i % 3), 40, 10 + i, 0.15), 0.8))
        parts.append((t0, metal_hit(240, 25, 20 + i, 0.2), 0.5))
    return norm(reverb(mix(parts, 1.1)[: int(1.1 * SR)], 0.2, 5, 0.6))


def key_melody():
    notes = [84, 88, 91, 96]
    parts = [(i * 0.09, bell(midi(m), 1.4, 1.4), 1.0) for i, m in enumerate(notes)]
    parts += [(0.36, bell(midi(103), 1.2, 0.6), 1.0)]
    k = np.arange(int(1.2 * SR)) / SR
    sparkle = np.zeros(len(k))
    for _ in range(18):
        i = int(rng.uniform(0.05, 0.9) * SR)
        f = rng.uniform(3500, 7000)
        s = np.sin(2 * np.pi * f * k[: int(0.12 * SR)]) * np.exp(-k[: int(0.12 * SR)] * 40)
        sparkle[i : i + len(s)] += s[: len(sparkle) - i] * 0.05
    parts.append((0, sparkle, 1.0))
    return norm(reverb(mix(parts, 1.6)[: int(1.6 * SR)], 0.25, 3, 1.0))


def key_fly():
    """Keys rising and flying away: a sparkly whoosh up."""
    d = 1.4
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 600 + 2400 * (t / d) ** 1.5
    whoosh = band(rng.standard_normal(n), 800, 7000) * np.sin(np.pi * t / d) ** 2 * 0.3
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / d) * 0.15
    parts = [(0, whoosh + tone, 1.0)]
    for i, m in enumerate((91, 95, 98, 103)):
        parts.append((0.2 + i * 0.22, bell(midi(m), 1.0, 1.2), 1.0))
    return norm(reverb(mix(parts, 1.9)[: int(1.9 * SR)], 0.3, 3, 1.0))


def fanfare():
    parts = []
    for i, m in enumerate([62, 66, 69, 74, 78, 81]):
        parts.append((i * 0.11, bell(midi(m + 12), 2.0, 1.2), 1.0))
        parts.append((i * 0.11, pluck(midi(m), 0.6), 0.5))
    for m in (74, 78, 81, 86):
        n = int(1.6 * SR)
        t = np.arange(n) / SR
        f = midi(m)
        brass = sum((1 / h) * np.sin(2 * np.pi * h * f * t) for h in range(1, 8)) * env(n, 0.05, 0.6) * 0.18
        parts.append((0.7, brass, 1.0))
    parts.append((0.7, bell(midi(98), 2.5, 1.0), 1.0))
    return norm(reverb(mix(parts, 2.8)[: int(2.8 * SR)], 0.3, 2.5, 1.4))


def purr():
    d = 2.6
    n = int(d * SR)
    t = np.arange(n) / SR
    am = 0.55 + 0.45 * np.sin(2 * np.pi * 25 * t) ** 2
    breath = np.where((t % 1.3) < 0.7, 1.0, 0.7)
    sig = band(rng.standard_normal(n), 60, 900) * am * breath
    return norm(sig * env(n, 0.3, 0.5), 0.7)


def snort():
    """A sudden snore and a gasp, about to wake."""
    g = np.random.default_rng(71)
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    body = shaped(g, n, [(380, 150, 1.0), (850, 280, 0.5), (1500, 450, 0.15)], 80, 2600, 0.2)
    buzz = flutter(g, n, 38 + 20 * t / 0.45, 5)
    burst = body * (0.2 + 0.8 * buzz) * curve(n, 0.5, 1.6) * np.minimum(t / 0.015, 1)
    m = int(0.5 * SR)
    gasp = shaped(None, m, [(800, 350, 0.8), (1900, 600, 0.9), (3000, 900, 0.3)], 250, 5000, 0.35, noise=rng.standard_normal(m))
    gasp *= curve(m, 1.4, 0.8) * 0.45
    return norm(np.concatenate([burst, gasp]))


def pop():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = 900 * np.exp(-t * 18) + 180
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 22)
    return norm(body + band(rng.standard_normal(n), 1000, 6000) * np.exp(-t * 90) * 0.4)


def mouse_squeaks():
    parts = []
    for i, (t0, f) in enumerate(((0, 3600), (0.16, 4100), (0.36, 3800))):
        n = int(0.09 * SR)
        t = np.arange(n) / SR
        ff = f + 500 * np.sin(np.pi * t / 0.09)
        parts.append((t0, np.sin(2 * np.pi * np.cumsum(ff) / SR) * env(n, 0.005, 0.03), 0.5))
    return norm(mix(parts, 0.6)[: int(0.6 * SR)], 0.7)


def pounce():
    d = 0.5
    n = int(d * SR)
    t = np.arange(n) / SR
    whoosh = band(rng.standard_normal(n), 400, 4000) * np.sin(np.pi * np.minimum(t / 0.35, 1)) ** 2 * 0.5
    m = int(0.3 * SR)
    k = np.arange(m) / SR
    thud = np.sin(2 * np.pi * (90 + 60 * np.exp(-k * 30)) * k) * np.exp(-k * 18)
    return norm(mix([(0, whoosh, 1.0), (0.33, thud, 1.0)], 0.7)[: int(0.7 * SR)])


def hearts():
    parts = [(i * 0.1, bell(midi(m), 1.2, 1.3), 1.0) for i, m in enumerate((84, 88, 91, 93, 96))]
    return norm(reverb(mix(parts, 1.7)[: int(1.7 * SR)], 0.35, 3, 1.0))


def paw(seed):
    g = np.random.default_rng(seed)
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    return norm(band(g.standard_normal(n), 120, 1400) * np.exp(-t * 55), 0.6)


def land():
    m = int(0.25 * SR)
    k = np.arange(m) / SR
    return norm(np.sin(2 * np.pi * (80 + 50 * np.exp(-k * 35)) * k) * np.exp(-k * 20) + band(rng.standard_normal(m), 150, 1200) * np.exp(-k * 40) * 0.5, 0.7)


def clock():
    parts = [(0, tick(3000, 1), 1.0), (0.5, tick(2300, 2), 0.8)]
    return norm(mix(parts, 1.0)[: int(1.0 * SR)], 0.6)


def creak():
    d = 1.3
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 160 + 90 * np.sin(2 * np.pi * 0.8 * t) + 20 * lowpass(rng.standard_normal(n), 400) * 30
    stick = (np.diff(np.floor(np.cumsum(np.maximum(f, 60)) / SR), prepend=0) > 0).astype(float)
    k = np.arange(int(0.01 * SR)) / SR
    ir = np.exp(-k * 300) * (np.sin(2 * np.pi * 900 * k) + 0.6 * np.sin(2 * np.pi * 1700 * k))
    return norm(np.convolve(stick, ir)[:n] * env(n, 0.1, 0.3), 0.7)


def whoosh():
    d = 0.4
    n = int(d * SR)
    t = np.arange(n) / SR
    return norm(band(rng.standard_normal(n), 900, 6000) * np.sin(np.pi * t / d) ** 2, 0.6)


def beep():
    n = int(0.14 * SR)
    t = np.arange(n) / SR
    return norm(np.sin(2 * np.pi * 1180 * t) * env(n, 0.005, 0.05), 0.6)


def alert():
    parts = []
    for i, f in enumerate((988, 740, 988, 740)):
        n = int(0.16 * SR)
        t = np.arange(n) / SR
        tone = np.tanh(1.6 * np.sin(2 * np.pi * f * t)) * env(n, 0.005, 0.03) * 0.5
        parts.append((i * 0.19, tone, 1.0))
    for m in (62, 61, 57):
        parts.append((0.8, bell(midi(m), 1.6, 1.3), 1.0))
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    parts.append((0.8, np.sin(2 * np.pi * (70 + 30 * np.exp(-t * 8)) * t) * np.exp(-t * 5) * 0.8, 1.0))
    return norm(reverb(mix(parts, 2.2)[: int(2.2 * SR)], 0.25, 3, 1.0))


def buzz():
    g = np.random.default_rng(21)
    parts = []
    for t0 in (0.0, 0.5):
        n = int(0.38 * SR)
        t = np.arange(n) / SR
        motor = np.sign(np.sin(2 * np.pi * 172 * t)) * 0.4 + np.sin(2 * np.pi * 344 * t) * 0.3
        rattle_ = lowpass(g.standard_normal(n), 3) * 0.25 * (np.sin(2 * np.pi * 43 * t) > 0)
        parts.append((t0, lowpass((motor + rattle_) * env(n, 0.02, 0.04), 4), 1.0))
    return norm(mix(parts, 0.95)[: int(0.95 * SR)], 0.8)


def ding():
    parts = [(0, bell(midi(88), 1.4, 1.4), 1.0), (0.16, bell(midi(93), 1.6, 1.4), 1.0)]
    return norm(reverb(mix(parts, 1.6)[: int(1.6 * SR)], 0.2, 3, 0.8))


def gate_motor():
    g = np.random.default_rng(31)
    d = 2.8
    n = int(d * SR)
    t = np.arange(n) / SR
    hum = (np.sin(2 * np.pi * 96 * t) + 0.5 * np.sin(2 * np.pi * 192 * t)) * 0.35
    roll = lowpass(g.standard_normal(n), 30) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t))
    squeal = 0.05 * np.sin(2 * np.pi * (1500 + 300 * np.sin(2 * np.pi * 0.7 * t)) * t)
    body = (hum + roll + squeal) * env(n, 0.25, 0.3)
    m = int(0.4 * SR)
    k = np.arange(m) / SR
    clank = (np.sin(2 * np.pi * 420 * k) * 0.6 + np.sin(2 * np.pi * 1130 * k) * 0.3 + g.standard_normal(m) * 0.3) * np.exp(-k * 14)
    out = np.zeros(n + m)
    out[:n] += body
    out[n - int(0.1 * SR) : n - int(0.1 * SR) + m] += clank
    return norm(out)


def sigh():
    """Settling back to sleep: a long soft sigh out."""
    g = np.random.default_rng(41)
    m = int(1.6 * SR)
    e = curve(m, 0.7, 2.2) * np.minimum(np.arange(m) / (0.05 * SR), 1)
    low = shaped(g, m, [(420, 220, 1.0), (1300, 450, 0.5), (2500, 700, 0.15)], 120, 3800, 0.55)
    air = shaped(g, m, [(900, 400, 0.6), (2000, 700, 0.45)], 220, 5000, 0.4)
    return norm(e * (low * 0.75 + air * 0.25 * e), 0.7)


def crickets():
    """Night in the yard: crickets chirping in pairs, a soft breeze."""
    g = np.random.default_rng(51)
    d = 6.0
    n = int(d * SR)
    t = np.arange(n) / SR
    out = band(g.standard_normal(n), 200, 1200) * 0.04
    for f0, start, every in ((4300, 0.1, 0.9), (4700, 0.45, 1.3), (3900, 0.7, 1.1)):
        k = start
        while k < d - 0.3:
            for j in range(3):
                i = int((k + j * 0.045) * SR)
                m = int(0.03 * SR)
                tt = np.arange(m) / SR
                chirp = np.sin(2 * np.pi * f0 * tt) * np.sin(np.pi * tt / 0.03) * 0.25
                out[i : i + m] += chirp[: len(out) - i]
            k += every + g.uniform(-0.1, 0.1)
    return norm(out, 0.6)


def servo():
    """A security camera turning: a thin motor whine."""
    d = 2.0
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 620 + 40 * np.sin(2 * np.pi * 0.5 * t)
    whine = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.3 + np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR) * 0.12
    return norm(whine * (0.8 + 0.2 * np.sin(2 * np.pi * 11 * t)), 0.5)


def click():
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    return norm(np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 120) + np.sin(2 * np.pi * 900 * t) * np.exp(-t * 60) * 0.5, 0.8)


def rumble():
    """A game controller stepped on: a button click, then it buzzes against the floor."""
    g = np.random.default_rng(61)
    parts = [(0.0, click() * 0.6, 1.0)]
    for t0, d in ((0.05, 0.42), (0.55, 0.3)):
        n = int(d * SR)
        t = np.arange(n) / SR
        motor = np.sin(2 * np.pi * 78 * t) * 0.5 + np.sign(np.sin(2 * np.pi * 156 * t)) * 0.2
        knock = lowpass(g.standard_normal(n), 2) * (np.sin(2 * np.pi * 36 * t) > 0.3) * 0.5
        parts.append((t0, lowpass((motor + knock) * env(n, 0.01, 0.06), 3), 1.0))
    return norm(mix(parts, 0.95)[: int(0.95 * SR)], 0.85)


def plastic_tap(seed, f0):
    g = np.random.default_rng(seed)
    m = int(0.09 * SR)
    k = np.arange(m) / SR
    tone = sum(a * np.sin(2 * np.pi * f0 * r * k) for r, a in ((1, 0.5), (1.52, 0.35), (2.31, 0.2)))
    return (tone + g.standard_normal(m) * 0.6 * np.exp(-k * 300)) * np.exp(-k * 70)


def clack():
    """Toy blocks knocked over: hollow plastic taps tumbling."""
    parts = []
    for i, (t0, f0, gain) in enumerate(((0.0, 1700, 1.0), (0.07, 2100, 0.8), (0.16, 1500, 0.9), (0.27, 2400, 0.6), (0.41, 1900, 0.45), (0.58, 2200, 0.3))):
        parts.append((t0, plastic_tap(70 + i, f0), gain))
    return norm(reverb(mix(parts, 0.8)[: int(0.8 * SR)], 0.15, 6, 0.4))


def clatter():
    """Lipsticks knocked over: little metal tubes tapping and rolling away."""
    g = np.random.default_rng(81)
    parts = []
    for i, t0 in enumerate((0.0, 0.05, 0.13, 0.22, 0.34, 0.5)):
        parts.append((t0, metal_hit(2300 + 260 * (i % 3), 45, 90 + i, 0.15), 1.0 - i * 0.12))
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    roll = band(g.standard_normal(n), 2500, 6000) * 0.12 * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t)) * np.exp(-t * 3) * np.minimum(t / 0.15, 1)
    parts.append((0.1, roll, 1.0))
    return norm(reverb(mix(parts, 1.1)[: int(1.1 * SR)], 0.15, 5, 0.5))


def clink():
    """A perfume bottle tipping over: two glassy clinks and a wobble."""
    parts = []
    for t0, f, gain in ((0.0, 2650, 1.0), (0.22, 2900, 0.7), (0.34, 2800, 0.35), (0.42, 2750, 0.2)):
        m = int(0.9 * SR)
        k = np.arange(m) / SR
        tone = sum(a * np.sin(2 * np.pi * f * r * k) * np.exp(-k * d) for r, a, d in ((1, 0.6, 7), (1.58, 0.3, 10), (2.61, 0.25, 14), (3.9, 0.1, 20)))
        parts.append((t0, tone, gain))
    return norm(reverb(mix(parts, 1.3)[: int(1.3 * SR)], 0.25, 4, 0.7))


def formant_env(f, formants):
    e = np.zeros_like(f) + 0.02
    for fc, bw, gain in formants:
        e += gain / (1 + ((f - fc) / (bw / 2)) ** 2)
    return e


def scream_part(dur, f0s, seed, vowel):
    g = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = np.interp(t, np.linspace(0, dur, len(f0s)), f0s)
    jitter = np.convolve(g.standard_normal(n), np.ones(800) / 800, mode="same") * 60
    f0 = f0 * (1 + 0.025 * np.sin(2 * np.pi * 6.2 * t)) + jitter
    phase = 2 * np.pi * np.cumsum(f0) / SR
    out = np.zeros(n)
    for k in range(1, 14):
        fk = f0 * k
        out += formant_env(fk, vowel) * (fk < 9000) / k ** 0.35 * np.sin(k * phase + g.uniform(0, 6.28))
    out *= 1 + 0.25 * np.sin(phase / 2)
    fr = np.fft.rfftfreq(n, 1 / SR)
    breath = np.fft.irfft(np.fft.rfft(g.standard_normal(n)) * formant_env(fr, vowel), n)
    out = out / np.abs(out).max() + breath / np.abs(breath).max() * 0.12
    shape = np.minimum(t / 0.05, 1) * np.minimum((dur - t) / 0.25, 1)
    return np.tanh(out * shape * 1.8)


def scream():
    """Milenkitka sees the dead mouse: a long scream, a gasp, a shorter one."""
    aa = [(1000, 260, 1.0), (1500, 300, 0.7), (2900, 400, 0.45), (3800, 500, 0.25)]
    ee = [(700, 240, 0.8), (2600, 350, 1.0), (3300, 450, 0.6), (4200, 500, 0.3)]
    first = scream_part(1.45, [560, 900, 960, 930, 980, 900, 760], 1, aa)
    m = int(0.18 * SR)
    gasp = band(np.random.default_rng(3).standard_normal(m), 300, 3000) * np.hanning(m) * 0.25
    second = scream_part(0.85, [700, 1080, 1120, 1050, 860], 2, ee) * 0.9
    return norm(reverb(np.concatenate([first, gasp, second]), 0.15, 5, 0.6))


def scratch():
    """A record scratch: the music stops."""
    g = np.random.default_rng(91)
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    rate = np.interp(t, [0, 0.12, 0.2, 0.45], [1.0, 2.6, 0.4, 0.05])
    phase = 2 * np.pi * np.cumsum(220 * rate) / SR
    tone = np.sign(np.sin(phase)) * 0.3 + np.sin(phase * 2) * 0.3
    hiss = band(g.standard_normal(n), 800, 7000) * 0.35 * rate / 2.6
    return norm((tone + hiss) * np.minimum(t / 0.01, 1) * np.exp(-t * 3), 0.85)


def drone():
    """Tension while a sleeper watches: a low hum that beats, with static on top. Loops in 4 s."""
    g = np.random.default_rng(61)
    n = int(4.0 * SR)
    t = np.arange(n) / SR
    # Every part repeats a whole number of times in 4 s so the loop is seamless
    hum = sum(a * np.sin(2 * np.pi * f * t + i) for i, (f, a) in enumerate(((55, 1.0), (56.5, 0.8), (82.5, 0.45), (110.25, 0.3), (165, 0.15))))
    hum *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.5 * t)
    static = band(g.standard_normal(n), 700, 5200) * (0.45 + 0.55 * np.abs(np.sin(2 * np.pi * 3 * t)))
    return norm(norm(hum, 0.7) + norm(static, 0.22), 0.8)


def voice(name, semis=0.0, tempo=1.0, wet=0.15):
    x = load_wav(os.path.join(ROOT, "sounds", "voice", name + ".wav"), semis, tempo)
    return norm(reverb(x, wet, 4, 0.6))


# Files ---------------------------------------------------------------------


def save_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def to_mp3(x, path, loud=None):
    """Writes an mp3. With loud, the music is brought to that loudness (LUFS) and its low end
    thinned so phone speakers play it clearly."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    save_wav(tmp, x)
    chain = []
    if loud is not None:
        shape = "highpass=f=90,equalizer=f=1800:t=q:w=1:g=3"
        probe = subprocess.run(["ffmpeg", "-hide_banner", "-i", tmp, "-af", f"{shape},loudnorm=I={loud}:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"], capture_output=True, text=True).stderr
        m = json.loads(probe[probe.rindex("{") : probe.rindex("}") + 1])
        chain = ["-af", f"{shape},loudnorm=I={loud}:TP=-1.5:LRA=11:linear=true:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}", "-ar", "44100"]
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", tmp, *chain, "-ac", "1", "-b:a", "128k", path], check=True)
    os.remove(tmp)


def main():
    clips = [
        ("Breath", snoring(False)), ("BreathLight", snoring(True)), ("Snort", snort()),
        ("Hmm", voice("hmm", -2, 0.9, 0.2)), ("HmmKid", voice("hmm_kid", 3, 0.9, 0.2)), ("Grumble", voice("mmm", -3, 0.85, 0.3)),
        ("Aww", voice("aww", 1, 0.95, 0.2)), ("Kiss", voice("kiss", 1, 1.0, 0.15)),
        ("Squeak", squeak(False)), ("Squeak2", squeak(True)), ("Track", ball_track()),
        ("Unlock", unlock()), ("Lock", lock_clunk()), ("Rattle", rattle()), ("Key", key_melody()), ("KeyFly", key_fly()),
        ("AllKeys", fanfare()), ("Purr", purr()), ("Pop", pop()), ("Mouse", mouse_squeaks()), ("Pounce", pounce()),
        ("Hearts", hearts()), ("Paw1", paw(1)), ("Paw2", paw(2)), ("Land", land()), ("Clock", clock()), ("Creak", creak()),
        ("Whoosh", whoosh()), ("Beep", beep()), ("Alert", alert()), ("Buzz", buzz()), ("Ding", ding()), ("Gate", gate_motor()),
        ("Sigh", sigh()), ("Crickets", crickets()), ("Servo", servo()), ("Click", click()),
        ("Rumble", rumble()), ("Clack", clack()), ("Clatter", clatter()), ("Clink", clink()),
        ("Scream", scream()), ("Scratch", scratch()), ("Drone", drone()),
    ]
    table, chunks, pos = {}, [np.zeros(int(0.3 * SR))], 0.3
    for name, x in clips:
        table[name] = [round(pos, 3), round(len(x) / SR, 3)]
        chunks += [x, np.zeros(int(0.3 * SR))]
        pos += len(x) / SR + 0.3
    os.makedirs(os.path.join(ROOT, "sounds"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "music"), exist_ok=True)
    to_mp3(np.concatenate(chunks), os.path.join(ROOT, "sounds", "PiankaEscapeSfx.mp3"))
    for name, x in (("PiankaSneak", stealth_calm()), ("PiankaTense", stealth_tense()), ("PiankaDream", dream_box())):
        to_mp3(x, os.path.join(ROOT, "music", name + ".mp3"), loud=-13)
        print(name, round(len(x) / SR, 2), "s")
    print(json.dumps(table))


if __name__ == "__main__":
    main()
