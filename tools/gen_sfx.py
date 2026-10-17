"""Synthesises the game-event sound effects into sounds/ (16-bit mono WAV).

Run from the repo root:  python tools/gen_sfx.py
Rules for when each sound plays: docs/design/player.md (그레이즈 · 피격 연출).
Deterministic (fixed seed), so re-running reproduces the committed files.
"""

import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "sounds"
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def sweep(f0, f1, seconds, curve=1.0):
    """Sine whose frequency glides f0 -> f1 (curve > 1 glides late)."""
    t = t_axis(seconds)
    k = (t / seconds) ** curve
    freq = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def lowpass(signal, cutoff):
    """One-pole low-pass; cutoff may be an array (per-sample) or a float."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), signal.shape)
    alpha = 1.0 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i, (x, a) in enumerate(zip(signal, alpha)):
        acc += a * (x - acc)
        out[i] = acc
    return out


def envelope(seconds, attack, decay_rate):
    t = t_axis(seconds)
    rise = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    return rise * np.exp(-t * decay_rate)


def fade_tail(signal, seconds=0.01):
    n = min(len(signal), int(RATE * seconds))
    signal[-n:] *= np.linspace(1.0, 0.0, n)
    return signal


def write(name, signal, peak):
    signal = fade_tail(signal.astype(float))
    signal = signal / max(1e-9, np.max(np.abs(signal))) * peak
    data = (signal * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / name), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data)
    print(f"{name}: {len(signal) / RATE:.3f}s")


def graze_tick():
    # A thin glassy tick: high sine with a few ms of air, gone in 40 ms.
    seconds = 0.04
    tone = sweep(3200, 2600, seconds) * 0.8 + sweep(6400, 5200, seconds) * 0.2
    air = lowpass(rng.uniform(-1, 1, len(tone)), 9000) * 0.25
    return (tone + air) * envelope(seconds, 0.001, 110)


def shield_hit():
    # Survivable hit: short, bright knock with a falling ping.
    seconds = 0.22
    knock = lowpass(rng.uniform(-1, 1, int(RATE * seconds)), 5000) * envelope(seconds, 0.0005, 45)
    ping = sweep(1500, 650, seconds, 0.6) * envelope(seconds, 0.001, 18)
    return knock * 0.8 + ping * 0.7


def shield_break():
    # Shield gone: low, long burst that crackles out.
    seconds = 0.8
    n = int(RATE * seconds)
    t = t_axis(seconds)
    cutoff = 3500 * np.exp(-t * 4.0) + 150
    rumble = lowpass(rng.uniform(-1, 1, n), cutoff) * envelope(seconds, 0.002, 4.5)
    drop = sweep(320, 60, seconds, 0.5) * envelope(seconds, 0.002, 5.0)
    crackle = (rng.uniform(0, 1, n) > 0.997) * rng.uniform(-1, 1, n)
    crackle = lowpass(crackle, 2500) * np.exp(-t * 3.0) * 3.0
    snap = lowpass(rng.uniform(-1, 1, n), 7000) * envelope(seconds, 0.0005, 60) * 0.6
    return rumble * 1.0 + drop * 0.8 + crackle + snap


def shield_restore():
    # One point back: two rising soft chimes (E6 -> B6).
    seconds = 0.42
    t = t_axis(seconds)
    out = np.zeros(len(t))
    for start, freq in ((0.0, 1318.5), (0.09, 1975.5)):
        offset = int(RATE * start)
        length = len(t) - offset
        tt = t[:length]
        tone = np.sin(2 * np.pi * freq * tt) + 0.3 * np.sin(2 * np.pi * freq * 2 * tt)
        out[offset:] += tone * envelope(length / RATE, 0.006, 9.0)
    shimmer = np.sin(2 * np.pi * 6.0 * t) * 0.08 + 1.0
    return out * shimmer


if __name__ == "__main__":
    write("graze_tick.wav", graze_tick(), 0.5)
    write("shield_hit.wav", shield_hit(), 0.8)
    write("shield_break.wav", shield_break(), 0.9)
    write("shield_restore.wav", shield_restore(), 0.6)
