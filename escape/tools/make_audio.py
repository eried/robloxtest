# Sounds and music for Pianka the Escape: python3 escape/tools/make_audio.py
# Writes escape/sounds/PiankaEscapeSfx.mp3, escape/music/PiankaSneak.mp3 and prints the clip table for Config.luau
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


def env(n, a, r):
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return e


def norm(x, peak=0.9):
    return x / max(np.abs(x).max(), 1e-9) * peak


def reverb(x, wet=0.25, decay=3.0, length=1.2):
    n = int(length * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t * decay)
    ir = lowpass(ir, 6)
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    w = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x) + n]
    out = np.zeros(len(w))
    out[: len(x)] += x
    return out * (1 - wet) + w * wet * np.abs(x).max() / max(np.abs(w).max(), 1e-9)


def bell(freq, dur=2.5, gain=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for ratio, amp, dec in ((1, 1, 1.4), (2.76, 0.4, 2.4), (5.4, 0.2, 3.6), (8.9, 0.08, 5)):
        sig += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * dec)
    return sig * env(n, 0.002, 0.2) * 0.12 * gain


def pluck(freq, dur=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for h in range(1, 12):
        sig += (1 / h) * np.exp(-t * (6.0 + h * 2.2)) * np.sin(2 * np.pi * h * freq * t)
    return sig * env(n, 0.003, 0.04) * 0.5


def mix(parts, total):
    out = np.zeros(int(total * SR) + SR)
    for t0, sig, gain in parts:
        i = int(t0 * SR)
        out[i : i + len(sig)] += sig[: len(out) - i] * gain
    return out


# Snoring: a fluttering inhale through the nose, a breathy exhale, a little pause
def snore(deep):
    d_in, d_out = 1.5, 1.25
    n = int(d_in * SR)
    t = np.arange(n) / SR
    f0 = (26 if deep else 34) + 6 * np.sin(np.pi * t / d_in)
    phase = np.cumsum(f0) / SR
    pulses = (np.diff(np.floor(phase), prepend=0) > 0).astype(float)
    k = np.arange(int(0.045 * SR)) / SR
    f1, f2 = (160, 380) if deep else (230, 520)
    ir = np.exp(-k * 55) * np.sin(2 * np.pi * f1 * k) + 0.6 * np.exp(-k * 90) * np.sin(2 * np.pi * f2 * k) + 0.25 * np.exp(-k * 130) * np.sin(2 * np.pi * 950 * k)
    rattle = np.convolve(pulses, ir)[:n]
    inhale = (norm(rattle) + lowpass(rng.standard_normal(n), 18) * 0.5) * np.sin(np.pi * t / d_in) ** 0.9
    m = int(d_out * SR)
    t2 = np.arange(m) / SR
    breath = lowpass(rng.standard_normal(m), 7) * 0.9 * np.sin(np.pi * t2 / d_out) ** 1.6
    whistle = 0.06 * np.sin(2 * np.pi * (650 + 80 * t2) * t2) * np.sin(np.pi * t2 / d_out) ** 2
    out = np.concatenate([inhale * 0.9, np.zeros(int(0.12 * SR)), breath * 0.45 + whistle, np.zeros(int(0.55 * SR))])
    return norm(out, 0.8)


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


def unlock():
    parts = []
    k = np.arange(int(0.08 * SR)) / SR
    for i, (t0, f) in enumerate(((0.0, 3200), (0.18, 2800), (0.36, 3400))):
        parts.append((t0, np.exp(-k * 160) * (np.sin(2 * np.pi * f * k) + 0.5 * rng.standard_normal(len(k))), 0.7))
    m = np.arange(int(0.35 * SR)) / SR
    clunk = np.exp(-m * 18) * np.sin(2 * np.pi * (90 + 40 * np.exp(-m * 30)) * m) + np.exp(-m * 60) * rng.standard_normal(len(m)) * 0.3
    parts.append((0.6, clunk, 1.0))
    return norm(mix(parts, 1.0)[: int(1.0 * SR)])


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
    sig = lowpass(rng.standard_normal(n), 40) * am * breath
    return norm(sig * env(n, 0.3, 0.5), 0.7)


def snort():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    pulses = (np.diff(np.floor(np.cumsum(40 + 30 * t) / SR), prepend=0) > 0).astype(float)
    k = np.arange(int(0.04 * SR)) / SR
    ir = np.exp(-k * 50) * np.sin(2 * np.pi * 200 * k)
    burst = np.convolve(pulses, ir)[:n] * np.exp(-t * 6)
    m = int(0.5 * SR)
    t2 = np.arange(m) / SR
    gasp = lowpass(rng.standard_normal(m), 4) * np.sin(np.pi * t2 / 0.5) * np.linspace(0.6, 1, m) * 0.6
    return norm(np.concatenate([norm(burst), gasp]))


def dream():
    parts = [(i * 0.07, bell(midi(m), 2.0, 1.0), 1.0) for i, m in enumerate([72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96])]
    return norm(reverb(mix(parts, 2.6)[: int(2.6 * SR)], 0.45, 1.8, 1.8))


def sneak_music():
    beat = 0.42
    bars = 16
    total = bars * 4 * beat
    parts = []
    chords = ["Dm", "Dm", "Bb", "A", "Dm", "Dm", "Gm", "A", "Dm", "F", "Bb", "A", "Gm", "Dm", "E", "A"]
    roots = {"Dm": 50, "Bb": 46, "A": 45, "Gm": 43, "F": 41, "E": 40}
    tune = [
        [(0, 74), (1, 76), (2, 77), (3, 76)], [(0, 74), (2, 73)], [(0, 77), (1, 76), (2, 74), (3, 70)], [(0, 69), (2, 73)],
        [(0, 74), (1, 76), (2, 77), (2.5, 79), (3, 81)], [(0, 82), (1, 81), (2, 77)], [(0, 79), (1, 77), (2, 76), (3, 74)], [(0, 73), (2, 69)],
    ]
    for bar in range(bars):
        t0 = bar * 4 * beat
        r = roots[chords[bar]]
        minor = chords[bar] in ("Dm", "Gm", "A") and chords[bar] != "A"
        third = 3 if minor else 4
        for b, step in enumerate([0, 7, 12, 7]):
            parts.append((t0 + b * beat, pluck(midi(r - 12 + step), 0.28), 0.9))
        for b in (1, 3):
            parts.append((t0 + b * beat, pluck(midi(r + third + 12), 0.2), 0.25))
            parts.append((t0 + b * beat, pluck(midi(r + 7 + 12), 0.2), 0.25))
        k = np.arange(int(0.06 * SR)) / SR
        for b in range(8):
            tick = lowpass(rng.standard_normal(len(k)), 2) * np.exp(-k * 90) * (0.06 if b % 2 else 0.035)
            parts.append((t0 + b * beat / 2, tick, 1.0))
        if bar >= 4:
            for when, m in tune[bar % 8]:
                parts.append((t0 + when * beat, bell(midi(m), 1.2, 1.0), 0.9))
    out = mix(parts, total + 2)
    loop = out[: int(total * SR)].copy()
    tail = out[int(total * SR) :]
    loop[: len(tail)] += tail
    return norm(reverb(loop, 0.18, 3, 1.0)[: len(loop)], 0.85)


def save_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def to_mp3(x, path):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    save_wav(tmp, x)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", tmp, "-ac", "1", "-b:a", "128k", path], check=True)
    os.remove(tmp)


def main():
    clips = [
        ("SnoreDeep", snore(True)), ("SnoreLight", snore(False)), ("Squeak", squeak(False)), ("Squeak2", squeak(True)),
        ("Track", ball_track()), ("Unlock", unlock()), ("Key", key_melody()), ("AllKeys", fanfare()),
        ("Purr", purr()), ("Snort", snort()), ("Dream", dream()),
    ]
    table, chunks, pos = {}, [np.zeros(int(0.3 * SR))], 0.3
    for name, x in clips:
        table[name] = [round(pos, 3), round(len(x) / SR, 3)]
        chunks += [x, np.zeros(int(0.3 * SR))]
        pos += len(x) / SR + 0.3
    os.makedirs(os.path.join(ROOT, "sounds"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "music"), exist_ok=True)
    to_mp3(np.concatenate(chunks), os.path.join(ROOT, "sounds", "PiankaEscapeSfx.mp3"))
    music = sneak_music()
    to_mp3(music, os.path.join(ROOT, "music", "PiankaSneak.mp3"))
    print(json.dumps(table))
    print("music", round(len(music) / SR, 2), "s")


if __name__ == "__main__":
    main()
